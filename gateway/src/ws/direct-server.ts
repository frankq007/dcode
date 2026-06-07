import { WebSocketServer, WebSocket, RawData } from 'ws';
import { randomUUID, randomBytes } from 'crypto';
import os from 'os';
import { CryptoManager } from '../crypto/crypto-manager';
import { OpencodeClient, OpencodeEvent } from '../opencode/opencode-client';
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
  private sseControllers: Map<string, AbortController> = new Map();
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
      this.cleanupSSEConnections();
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
      const encrypted = JSON.parse(data.toString());
      try {
        const decrypted = this.crypto.decrypt(encrypted);
        const message = JSON.parse(decrypted);
        this.processDecryptedMessage(message);
      } catch (e: any) {
        console.error('[Direct] Decryption/parse error:', e.message);
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
      
      const gatewayNonce = randomBytes(16).toString('base64');
      
      const ack: HandshakeMessage = {
        type: 'handshake_ack',
        publicKey: this.crypto.getPublicKeyBase64(),
        nonce: gatewayNonce,
        version: this.config.version
      };
      
      ws.send(JSON.stringify(ack));
      this.handshakeState = 'step1';
      
      (ws as any)._appNonce = msg.nonce;
      (ws as any)._appPublicKey = msg.publicKey;
      (ws as any)._gatewayNonce = gatewayNonce;
    } else if (this.handshakeState === 'step1' && msg.type === 'handshake_complete') {
      const appNonce = (ws as any)._appNonce;
      const gatewayNonce = (ws as any)._gatewayNonce;
      const appPublicKey = (ws as any)._appPublicKey;
      
      this.crypto.deriveSessionKey(appPublicKey, appNonce, gatewayNonce);
      this.handshakeState = 'complete';
      
      console.log('[Direct] Handshake complete: session key derived');
      
      const initialSession = this.sessions.create('Default');
      this.startSSESubscription(initialSession.id);
      
      this.sendEncryptedMessage({
        type: 'reply',
        id: randomUUID(),
        data: { message: 'Connected successfully' },
        timestamp: Date.now()
      });
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
      case 'token_info':
        this.handleTokenInfoRequest();
        break;
      default:
        console.log(`[Direct] Unknown message type: ${message.type}`);
    }
  }

  private async handleTokenInfoRequest(): Promise<void> {
    const session = this.sessions.getActive();
    if (!session) return;

    try {
      const tokenInfo = await this.opencode.getTokenUsage(session.id);
      this.sendEncryptedMessage({
        type: 'token_info',
        id: randomUUID(),
        data: tokenInfo,
        timestamp: Date.now()
      });
    } catch (e: any) {
      this.sendError(`Failed to get token usage: ${e.message}`);
    }
  }

  private async handleUserMessage(message: Message): Promise<void> {
    const session = this.sessions.getActive();
    if (!session) {
      this.sendError('No active session');
      return;
    }
    
    this.sessions.touch(session.id);
    
    try {
      await this.opencode.sendMessage(session.id, message.data.content);
    } catch (e: any) {
      this.sendError(`Failed to send message: ${e.message}`);
    }
  }

  private async handlePermissionReply(message: Message): Promise<void> {
    const session = this.sessions.getActive();
    if (!session) return;
    
    try {
      await this.opencode.handlePermissionReply(session.id, message.data.requestId, message.data.allowed);
    } catch (e: any) {
      this.sendError(`Failed to send permission reply: ${e.message}`);
    }
  }

  private async handleSessionCreate(message: Message): Promise<void> {
    try {
      const session = this.sessions.create(message.data.name);
      this.startSSESubscription(session.id);
      
      this.sendEncryptedMessage({
        type: 'session_list',
        id: randomUUID(),
        data: { sessions: this.sessions.list() },
        timestamp: Date.now()
      });
    } catch (e: any) {
      this.sendError(`Failed to create session: ${e.message}`);
    }
  }

  private handleSessionSwitch(message: Message): void {
    const session = this.sessions.switch(message.data.sessionId);
    if (session) {
      this.startSSESubscription(session.id);
      this.sendEncryptedMessage({
        type: 'session_switch',
        id: randomUUID(),
        data: { sessionId: session.id, name: session.name },
        timestamp: Date.now()
      });
    }
  }

  private startSSESubscription(sessionId: string): void {
    this.cleanupSSEConnections();
    
    const controller = this.opencode.subscribeToEvents(sessionId, (event: OpencodeEvent) => {
      const message: Message = {
        type: this.mapSSEEventType(event.type),
        id: randomUUID(),
        data: event.data,
        timestamp: Date.now()
      };
      this.sendEncryptedMessage(message);
    });
    
    this.sseControllers.set(sessionId, controller);
  }

  private mapSSEEventType(type: string): Message['type'] {
    const mapping: Record<string, Message['type']> = {
      'thinking': 'thinking',
      'tool_call': 'tool_call',
      'permission_request': 'permission_request',
      'reply': 'reply',
      'token_usage': 'token_info',
      'error': 'error',
      'review_url': 'review_url'
    };
    return mapping[type] || 'reply';
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

  private sendError(message: string): void {
    this.sendEncryptedMessage({
      type: 'error',
      id: randomUUID(),
      data: { message },
      timestamp: Date.now()
    });
  }

  private cleanupSSEConnections(): void {
    for (const [id, controller] of this.sseControllers) {
      controller.abort();
    }
    this.sseControllers.clear();
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
    this.cleanupSSEConnections();
    if (this.appWs) {
      this.appWs.close();
    }
    this.wss.close();
    console.log('[Direct] Server stopped');
  }
}
