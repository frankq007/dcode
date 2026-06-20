import { WebSocketServer, WebSocket, RawData } from 'ws';
import { randomUUID, randomBytes } from 'crypto';
import os from 'os';
import { CryptoManager } from '../crypto/crypto-manager';
import { OpencodeClient, OpencodePart, OpencodeMessageInfo } from '../opencode/opencode-client';
import { SessionManager } from '../session/session-manager';
import { GatewayConfig } from '../config';
import { HandshakeMessage, Message, QRCodeData } from '../types';

export class DirectServer {
  private wss: WebSocketServer;
  private crypto: CryptoManager;
  private config: GatewayConfig;
  private token: string;
  private appWs: WebSocket | null = null;
  private handshakeState: 'waiting' | 'step1' | 'complete' = 'waiting';
  private opencode: OpencodeClient;
  private sessions: SessionManager;
  private seenMessageIds: Set<string> = new Set();
  private maxMessageSize = 1024 * 1024; // 1MB

  constructor(config: GatewayConfig) {
    this.config = config;
    this.crypto = new CryptoManager();
    this.token = randomUUID();
    this.opencode = new OpencodeClient(config.opencodeUrl);
    this.sessions = new SessionManager();
    
    this.wss = new WebSocketServer({ host: config.host, port: config.port });
    this.setupServer();
  }

  private setupServer(): void {
    this.wss.on('listening', () => {
      console.log(`[Direct] WebSocket server listening on ${this.config.host}:${this.config.port}`);
      this.printQRCode();
    });

    this.wss.on('connection', (ws: WebSocket) => {
      if (this.appWs && this.appWs.readyState === WebSocket.OPEN) {
        console.log('[Direct] Rejecting new connection: existing app connected');
        ws.send(JSON.stringify({ type: 'error', data: { message: 'Another app is already connected' } }));
        ws.close();
        return;
      }

      console.log('[Direct] New app connection');
      this.appWs = ws;
      this.handshakeState = 'waiting';
      
      this.setupAppConnection(ws);
    });
  }

  private setupAppConnection(ws: WebSocket): void {
    ws.on('message', (data: RawData) => {
      this.handleAppMessage(ws, data);
    });

    ws.on('close', () => {
      console.log('[Direct] App disconnected');
      this.appWs = null;
      this.handshakeState = 'waiting';
      this.seenMessageIds.clear();
    });

    ws.on('error', (error) => {
      console.error('[Direct] WebSocket error:', error.message);
    });
  }

  private handleAppMessage(ws: WebSocket, data: RawData): void {
    if (this.handshakeState === 'complete') {
      try {
        const encrypted = JSON.parse(data.toString());
        const decrypted = this.crypto.decrypt(encrypted);
        const message = JSON.parse(decrypted);
        this.processDecryptedMessage(message);
      } catch (e: any) {
        console.error('[Direct] Decryption/parse error:', e.message);
        this.sendError('Data parse error', 'BAD_FRAME');
      }
    } else {
      try {
        const handshake = JSON.parse(data.toString()) as HandshakeMessage;
        this.handleHandshake(ws, handshake);
      } catch (e: any) {
        console.error('[Direct] Handshake parse error:', e.message);
        ws.close();
      }
    }
  }

  private handleHandshake(ws: WebSocket, msg: HandshakeMessage): void {
    if (this.handshakeState === 'waiting' && msg.type === 'handshake_init') {
      console.log(`[Direct] Handshake step 1: received app public key, version=${msg.version}`);

      if (msg.token !== this.token) {
        console.warn('[Direct] Invalid token, rejecting connection');
        ws.send(JSON.stringify({ type: 'error', data: { code: 'INVALID_TOKEN', message: 'Token invalid' } }));
        ws.close();
        return;
      }

      const gatewayNonce = randomBytes(16).toString('base64');

      (ws as any)._appNonce = msg.nonce;
      (ws as any)._appPublicKey = msg.publicKey;
      (ws as any)._gatewayNonce = gatewayNonce;

      this.crypto.deriveSessionKey(msg.publicKey, msg.nonce, gatewayNonce);

      const verify = this.crypto.createHandshakeVerify(msg.nonce, gatewayNonce, true);

      const ack: HandshakeMessage = {
        type: 'handshake_ack',
        publicKey: this.crypto.getPublicKeyBase64(),
        nonce: gatewayNonce,
        version: this.config.version,
        verify
      };

      ws.send(JSON.stringify(ack));
      this.handshakeState = 'step1';
    } else if (this.handshakeState === 'step1' && msg.type === 'handshake_complete') {
      const appNonce = (ws as any)._appNonce;
      const gatewayNonce = (ws as any)._gatewayNonce;

      if (!msg.verify || !this.crypto.verifyHandshake(msg.verify, appNonce, gatewayNonce, false)) {
        console.warn('[Direct] Handshake verify failed');
        ws.send(JSON.stringify({ type: 'error', data: { code: 'HANDSHAKE_FAILED', message: 'Key verification failed' } }));
        ws.close();
        return;
      }

      this.handshakeState = 'complete';
      console.log('[Direct] Handshake complete: session key verified');

      this.initializeFirstSession().catch((e: any) => {
        console.error('[Direct] Session initialization failed:', e.message);
        this.sendError(`Session initialization failed: ${e.message}`, 'INTERNAL');
      });
    }
  }

  private async initializeFirstSession(): Promise<void> {
    let activeSessionId: string | null = null;

    try {
      const existing = await this.opencode.listSessions();
      if (existing.length > 0) {
        for (const s of existing) {
          this.sessions.create(s.id, s.title);
        }
        activeSessionId = existing[0].id;
        this.sessions.switch(activeSessionId);
      }
    } catch (e: any) {
      console.warn('[Direct] Failed to list sessions, will create new:', e.message);
    }

    if (!activeSessionId) {
      const created = await this.opencode.createSession();
      this.sessions.create(created.id, created.title);
      activeSessionId = created.id;
    }

    await this.pushSessionList();
    await this.pushHistory(activeSessionId);
  }

  private async pushSessionList(): Promise<void> {
    this.sendEncryptedMessage({
      type: 'session_list',
      id: randomUUID(),
      data: { sessions: this.sessions.list().map(s => ({ id: s.id, name: s.name })) },
      timestamp: Date.now()
    });
  }

  private async pushHistory(sessionId: string): Promise<void> {
    try {
      const history = await this.opencode.getMessages(sessionId);
      this.sendEncryptedMessage({
        type: 'history',
        id: randomUUID(),
        data: {
          sessionId,
          messages: history,
          hasMore: false,
          cursor: undefined
        },
        timestamp: Date.now()
      });
    } catch (e: any) {
      console.warn('[Direct] Failed to load history:', e.message);
    }
  }

  private processDecryptedMessage(message: Message): void {
    if (this.seenMessageIds.has(message.id)) {
      console.log(`[Direct] Duplicate message ignored: ${message.id}`);
      return;
    }
    this.seenMessageIds.add(message.id);

    switch (message.type) {
      case 'user_message':
        this.handleUserMessage(message);
        break;
      case 'permission_reply':
        this.handlePermissionReply(message);
        break;
      case 'session_create':
        this.handleSessionCreate(message);
        break;
      case 'session_switch':
        this.handleSessionSwitch(message);
        break;
      case 'session_delete':
        this.handleSessionDelete(message);
        break;
      case 'session_list':
        this.pushSessionList();
        break;
      case 'token_query':
        this.handleTokenQuery();
        break;
      case 'heartbeat':
        break;
      default:
        console.log(`[Direct] Unknown message type: ${message.type}`);
    }
  }

  private async handleTokenQuery(): Promise<void> {
    const session = this.sessions.getActive();
    if (!session) return;

    try {
      const msgs = await this.opencode.getMessages(session.id);
      const lastAssistant = [...msgs].reverse().find(m => m.info.role === 'assistant');
      const tokens = lastAssistant?.info?.tokens;
      if (tokens) {
        this.sendEncryptedMessage({
          type: 'token_info',
          id: randomUUID(),
          data: {
            total: tokens.total,
            input: tokens.input,
            output: tokens.output,
            contextWindow: 4096
          },
          timestamp: Date.now()
        });
      }
    } catch (e: any) {
      this.sendError(`Failed to get token usage: ${e.message}`, 'INTERNAL');
    }
  }

  private async handleUserMessage(message: Message): Promise<void> {
    const session = this.sessions.getActive();
    if (!session) {
      this.sendError('No active session', 'SESSION_NOT_FOUND');
      return;
    }

    this.sessions.touch(session.id);

    this.sendEncryptedMessage({
      type: 'message_ack',
      id: randomUUID(),
      data: { id: message.id, status: 'accepted' },
      timestamp: Date.now()
    });

    try {
      await this.opencode.sendMessage(session.id, message.data.content, (part, msgInfo) => {
        this.forwardPartToApp(part, msgInfo);
      });
    } catch (e: any) {
      this.sendError(`Failed to send message: ${e.message}`, 'INTERNAL');
    }
  }

  private forwardPartToApp(part: OpencodePart, msgInfo: OpencodeMessageInfo): void {
    switch (part.type) {
      case 'reasoning':
        this.sendEncryptedMessage({
          type: 'thinking',
          id: part.id,
          data: { content: part.text || '' },
          timestamp: Date.now()
        });
        break;
      case 'text':
        this.sendEncryptedMessage({
          type: 'reply',
          id: part.id,
          data: { content: part.text || '' },
          timestamp: Date.now()
        });
        break;
      case 'tool':
        this.sendEncryptedMessage({
          type: 'tool_call',
          id: part.id,
          data: {
            toolName: part.toolName || 'unknown',
            parameters: part.input || {},
            result: part.output || ''
          },
          timestamp: Date.now()
        });
        break;
      case 'step-finish':
        if (part.tokens) {
          this.sendEncryptedMessage({
            type: 'token_info',
            id: part.id,
            data: {
              total: part.tokens.total,
              input: part.tokens.input,
              output: part.tokens.output,
              contextWindow: 4096
            },
            timestamp: Date.now()
          });
        }
        break;
      case 'patch':
        this.sendEncryptedMessage({
          type: 'review_url',
          id: part.id,
          data: { url: `session/${msgInfo.sessionID}` },
          timestamp: Date.now()
        });
        break;
      default:
        break;
    }
  }

  private async handlePermissionReply(message: Message): Promise<void> {
    try {
      await this.opencode.respondPermission(message.data.requestId, message.data.allowed);
    } catch (e: any) {
      this.sendError(`Failed to send permission reply: ${e.message}`, 'INTERNAL');
    }
  }

  private async handleSessionDelete(message: Message): Promise<void> {
    try {
      await this.opencode.deleteSession(message.data.sessionId);
      this.sessions.delete(message.data.sessionId);
      await this.pushSessionList();
    } catch (e: any) {
      this.sendError(`Failed to delete session: ${e.message}`, 'INTERNAL');
    }
  }

  private async handleSessionCreate(message: Message): Promise<void> {
    try {
      const created = await this.opencode.createSession();
      this.sessions.create(created.id, created.title);

      await this.pushSessionList();
    } catch (e: any) {
      this.sendError(`Failed to create session: ${e.message}`, 'INTERNAL');
    }
  }

  private async handleSessionSwitch(message: Message): Promise<void> {
    const session = this.sessions.switch(message.data.sessionId);
    if (session) {
      this.sendEncryptedMessage({
        type: 'session_switch',
        id: randomUUID(),
        data: { sessionId: session.id, name: session.name },
        timestamp: Date.now()
      });
      await this.pushHistory(session.id);
    }
  }

  private sendEncryptedMessage(message: Message): void {
    if (!this.appWs || this.appWs.readyState !== WebSocket.OPEN) return;
    
    const plaintext = JSON.stringify(message);
    const chunks = this.chunkMessage(plaintext);
    
    for (const chunk of chunks) {
      const encrypted = this.crypto.encrypt(chunk);
      this.appWs.send(JSON.stringify(encrypted));
    }
  }

  private chunkMessage(plaintext: string): string[] {
    const encoder = new TextEncoder();
    const encoded = encoder.encode(plaintext);
    
    if (encoded.length <= this.maxMessageSize) {
      return [plaintext];
    }
    
    const chunks: string[] = [];
    const decoder = new TextDecoder();
    let offset = 0;
    
    while (offset < encoded.length) {
      const end = Math.min(offset + this.maxMessageSize, encoded.length);
      chunks.push(decoder.decode(encoded.slice(offset, end)));
      offset = end;
    }
    
    return chunks;
  }

  private sendError(message: string, code: string = 'INTERNAL'): void {
    this.sendEncryptedMessage({
      type: 'error',
      id: randomUUID(),
      data: { code, message },
      timestamp: Date.now()
    });
  }


  private async printQRCode(): Promise<void> {
    const qrData: QRCodeData = {
      mode: 'direct',
      name: this.config.computerName,
      host: this.getLocalIP(),
      port: this.config.port,
      publicKey: this.crypto.getPublicKeyBase64(),
      token: this.token
    };

    const qrString = JSON.stringify(qrData);
    
    try {
      const qrcode = await import('qrcode-terminal');
      qrcode.generate(qrString, { small: true }, (qr: string) => {
        console.log('\n[Direct] Scan this QR code to connect:');
        console.log(qr);
      });
    } catch {
      console.log('\n[Direct] QR Code Data (manual entry):');
      console.log(qrString);
    }
  }

  private getLocalIP(): string {
    const interfaces = os.networkInterfaces();
    for (const name of Object.keys(interfaces)) {
      for (const iface of interfaces[name] || []) {
        if (iface.family === 'IPv4' && !iface.internal) {
          return iface.address;
        }
      }
    }
    return '127.0.0.1';
  }

  public stop(): void {
    if (this.appWs) {
      this.appWs.close();
    }
    this.wss.close();
    console.log('[Direct] Server stopped');
  }
}
