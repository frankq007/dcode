import WebSocket, { RawData } from 'ws';
import { randomUUID, randomBytes } from 'crypto';
import { CryptoManager } from '../crypto/crypto-manager';
import { OpencodeClient, OpencodePart, OpencodeMessageInfo } from '../opencode/opencode-client';
import { SessionManager } from '../session/session-manager';
import { OfflineEventBuffer } from '../session/offline-buffer';
import { GatewayConfig } from '../config';
import { HandshakeMessage, Message, QRCodeData } from '../types';

export class RelayClient {
  private ws: WebSocket | null = null;
  private crypto: CryptoManager;
  private config: GatewayConfig;
  private token: string;
  private reconnectAttempts = 0;
  private maxReconnectAttempts = 10;
  private reconnectDelay = 1000;
  private maxReconnectDelay = 30000;
  private isReconnecting = false;
  private handshakeState: 'waiting' | 'step1' | 'complete' = 'waiting';
  private opencode: OpencodeClient;
  private sessions: SessionManager;
  private offlineBuffer: OfflineEventBuffer = new OfflineEventBuffer();
  private seenMessageIds: Set<string> = new Set();

  constructor(config: GatewayConfig) {
    this.config = config;
    this.crypto = new CryptoManager();
    this.token = config.token || randomUUID();
    this.opencode = new OpencodeClient(config.opencodeUrl);
    this.sessions = new SessionManager();
  }

  start(): void {
    this.connectToRelay();
    this.printQRCode();
  }

  private connectToRelay(): void {
    console.log(`[Relay] Connecting to ${this.config.relayUrl}`);
    
    this.ws = new WebSocket(this.config.relayUrl);
    
    this.ws.on('open', () => {
      console.log('[Relay] Connected to relay server');
      this.reconnectAttempts = 0;
      this.reconnectDelay = 1000;
      
      const registerMsg = {
        type: 'register',
        token: this.token,
        role: 'gateway'
      };
      
      this.ws?.send(JSON.stringify(registerMsg));
    });

    this.ws.on('message', (data: RawData) => {
      this.handleMessage(data);
    });

    this.ws.on('close', () => {
      console.log('[Relay] Disconnected from relay server');
      this.cleanupConnection();
      this.attemptReconnect();
    });

    this.ws.on('error', (error) => {
      console.error('[Relay] WebSocket error:', error.message);
    });
  }

  private handleMessage(data: RawData): void {
    const message = data.toString();
    let parsed: any;
    
    try {
      parsed = JSON.parse(message);
    } catch (e) {
      console.error('[Relay] Parse error:', e);
      return;
    }

    if (parsed.type === 'waiting') {
      console.log('[Relay] Waiting for app to connect...');
    } else if (parsed.type === 'paired') {
      console.log('[Relay] Paired with app');
    } else if (parsed.type === 'peer_disconnected') {
      console.log('[Relay] App disconnected');
      this.cleanupConnection();
    } else if (this.handshakeState === 'complete') {
      this.handleEncryptedMessage(parsed);
    } else {
      this.handleHandshakeMessage(parsed);
    }
  }

  private handleHandshakeMessage(msg: any): void {
    if (this.handshakeState === 'waiting' && msg.type === 'handshake_init') {
      console.log(`[Relay] Handshake step 1: received app public key, version=${msg.version}`);

      if (msg.token !== this.token) {
        console.warn('[Relay] Invalid token, rejecting');
        this.ws?.send(JSON.stringify({ type: 'error', data: { code: 'INVALID_TOKEN', message: 'Token invalid' } }));
        return;
      }

      const gatewayNonce = randomBytes(16).toString('base64');

      (this as any)._appNonce = msg.nonce;
      (this as any)._appPublicKey = msg.publicKey;
      (this as any)._gatewayNonce = gatewayNonce;

      this.crypto.deriveSessionKey(msg.publicKey, msg.nonce, gatewayNonce);

      const verify = this.crypto.createHandshakeVerify(msg.nonce, gatewayNonce, true);

      const ack: HandshakeMessage = {
        type: 'handshake_ack',
        publicKey: this.crypto.getPublicKeyBase64(),
        nonce: gatewayNonce,
        version: this.config.version,
        verify
      };

      this.ws?.send(JSON.stringify(ack));
      this.handshakeState = 'step1';
    } else if (this.handshakeState === 'step1' && msg.type === 'handshake_complete') {
      const appNonce = (this as any)._appNonce;
      const gatewayNonce = (this as any)._gatewayNonce;

      if (!msg.verify || !this.crypto.verifyHandshake(msg.verify, appNonce, gatewayNonce, false)) {
        console.warn('[Relay] Handshake verify failed');
        this.ws?.send(JSON.stringify({ type: 'error', data: { code: 'HANDSHAKE_FAILED', message: 'Key verification failed' } }));
        return;
      }

      this.handshakeState = 'complete';
      console.log('[Relay] Handshake complete: session key verified');

      // Send connection ack immediately to prevent WebSocket idle timeout
      this.sendEncryptedMessage({
        type: 'reply',
        id: randomUUID(),
        data: { content: '连接成功，正在加载会话...' },
        timestamp: Date.now()
      });

      this.initializeFirstSession().catch((e: any) => {
        console.error('[Relay] Session initialization failed:', e.message);
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
      console.warn('[Relay] Failed to list sessions, will create new:', e.message);
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
      const allHistory = await this.opencode.getMessages(sessionId);
      const recent = allHistory.slice(-20);
      this.sendEncryptedMessage({
        type: 'history',
        id: randomUUID(),
        data: { sessionId, messages: recent, hasMore: allHistory.length > 20, cursor: undefined },
        timestamp: Date.now()
      });
    } catch (e: any) {
      console.warn('[Relay] Failed to load history:', e.message);
    }
  }

  private handleEncryptedMessage(encrypted: any): void {
    try {
      const decrypted = this.crypto.decrypt(encrypted);
      const message = JSON.parse(decrypted);
      this.processDecryptedMessage(message);
    } catch (e: any) {
      console.error('[Relay] Decryption/parse error:', e.message);
      this.sendError('Data parse error', 'BAD_FRAME');
    }
  }

  private processDecryptedMessage(message: Message): void {
    if (this.seenMessageIds.has(message.id)) {
      console.log(`[Relay] Duplicate message ignored: ${message.id}`);
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
      case 'sync':
        this.handleSync(message);
        break;
      case 'heartbeat':
        this.sendEncryptedMessage({
          type: 'heartbeat',
          id: randomUUID(),
          data: { timestamp: Date.now() },
          timestamp: Date.now()
        });
        break;
      default:
        console.warn(`[Relay] Unknown message type: ${message.type}`);
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

  private handleSync(message: Message): void {
    const session = this.sessions.getActive();
    if (!session) {
      console.warn('[Relay] Sync received but no active session');
      return;
    }

    const lastSeq = (message.data as any).lastSeq || 0;
    console.log(`[Relay] Sync request: lastSeq=${lastSeq}, session=${session.id}`);

    const events = this.offlineBuffer.since(session.id, lastSeq);
    console.log(`[Relay] Replaying ${events.length} offline events for session ${session.id}`);

    for (const event of events) {
      this.sendEncryptedMessage(event);
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
          type: 'thinking', id: part.id, stream: 'end',
          data: { content: part.text || '' }, timestamp: Date.now()
        });
        break;
      case 'text':
        this.sendEncryptedMessage({
          type: 'reply', id: part.id, stream: 'end',
          data: { content: part.text || '' }, timestamp: Date.now()
        });
        break;
      case 'tool':
        this.sendEncryptedMessage({
          type: 'tool_call', id: part.id, stream: 'end',
          data: { toolName: part.toolName || 'unknown', parameters: part.input || {}, result: part.output || '' },
          timestamp: Date.now()
        });
        break;
      case 'step-finish':
        if (part.tokens) {
          this.sendEncryptedMessage({
            type: 'token_info', id: part.id,
            data: { total: part.tokens.total, input: part.tokens.input, output: part.tokens.output, contextWindow: 4096 },
            timestamp: Date.now()
          });
        }
        break;
      case 'patch':
        this.sendEncryptedMessage({
          type: 'review_url', id: part.id,
          data: { url: `session/${msgInfo.sessionID}` }, timestamp: Date.now()
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
        type: 'session_switch', id: randomUUID(),
        data: { sessionId: session.id, name: session.name }, timestamp: Date.now()
      });
      await this.pushHistory(session.id);
    }
  }

  private async handleSessionDelete(message: Message): Promise<void> {
    try {
      await this.opencode.deleteSession(message.data.sessionId);
      this.sessions.delete(message.data.sessionId);
      this.offlineBuffer.clearSession(message.data.sessionId);
      await this.pushSessionList();
    } catch (e: any) {
      this.sendError(`Failed to delete session: ${e.message}`, 'INTERNAL');
    }
  }

  private sendEncryptedMessage(message: Message): void {
    if (this.offlineBuffer.isEventType(message.type)) {
      const session = this.sessions.getActive();
      if (session) {
        const seq = this.offlineBuffer.nextSeq(session.id);
        message.seq = seq;
        this.offlineBuffer.store(session.id, message);
        this.sessions.updateSeq(session.id, seq);
      }
    }

    if (!this.ws || this.ws.readyState !== WebSocket.OPEN) {
      console.log(`[Relay] Socket closed, event buffered (type=${message.type}, seq=${message.seq})`);
      return;
    }
    if (this.handshakeState !== 'complete') return;

    const plaintext = JSON.stringify(message);
    const encrypted = this.crypto.encrypt(plaintext);
    this.ws.send(JSON.stringify(encrypted));
  }

  private sendError(message: string, code: string = 'INTERNAL'): void {
    this.sendEncryptedMessage({
      type: 'error',
      id: randomUUID(),
      data: { code, message },
      timestamp: Date.now()
    });
  }

  private cleanupConnection(): void {
    this.handshakeState = 'waiting';
    this.seenMessageIds.clear();
  }

  private attemptReconnect(): void {
    if (this.isReconnecting) return;
    if (this.reconnectAttempts >= this.maxReconnectAttempts) {
      console.error('[Relay] Max reconnect attempts reached');
      return;
    }

    this.isReconnecting = true;
    this.reconnectAttempts++;
    
    const delay = Math.min(this.reconnectDelay * Math.pow(2, this.reconnectAttempts - 1), this.maxReconnectDelay);
    console.log(`[Relay] Reconnecting in ${delay}ms (attempt ${this.reconnectAttempts}/${this.maxReconnectAttempts})`);

    setTimeout(() => {
      this.isReconnecting = false;
      this.connectToRelay();
    }, delay);
  }

  private async printQRCode(): Promise<void> {
    const qrData: QRCodeData = {
      mode: 'relay',
      name: this.config.computerName,
      host: this.config.host,
      port: this.config.port,
      publicKey: this.crypto.getPublicKeyBase64(),
      token: this.token,
      relayUrl: this.config.relayUrl
    };

    const qrString = JSON.stringify(qrData);
    
    try {
      const qrcode = await import('qrcode-terminal');
      qrcode.generate(qrString, { small: true }, (qr: string) => {
        console.log('\n[Relay] Scan this QR code to connect:');
        console.log(qr);
      });
    } catch {
      console.log('\n[Relay] QR Code Data (manual entry):');
      console.log(qrString);
    }
  }

  public stop(): void {
    if (this.ws) {
      this.ws.close();
    }
    console.log('[Relay] Client stopped');
  }
}
