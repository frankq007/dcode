import { WebSocketServer, WebSocket, RawData } from 'ws';
import { randomUUID, randomBytes } from 'crypto';
import os from 'os';
import { CryptoManager } from '../crypto/crypto-manager';
import { OpencodeClient, OpencodePart, OpencodeMessageInfo, OpencodeEvent } from '../opencode/opencode-client';
import { SessionManager } from '../session/session-manager';
import { OfflineEventBuffer } from '../session/offline-buffer';
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
  private offlineBuffer: OfflineEventBuffer = new OfflineEventBuffer();
  private seenMessageIds: Set<string> = new Set();
  private maxMessageSize = 1024 * 1024; // 1MB
  private pendingSyncSeq: number = -1;
  private sessionInitDone: boolean = false;
  private pingTimer: NodeJS.Timeout | null = null;
  private messageQueue: Message[] = [];
  private isProcessingMessage: boolean = false;
  private sseStarted: boolean = false;
  private activeStream: {
    sessionId: string;
    thinkingId: string;
    thinkingText: string;
    replyPartId: string;
    replyStarted: boolean;
    assistantMsgId: string | null;
  } | null = null;
  private streamResolve: (() => void) | null = null;
  private streamReject: ((e: any) => void) | null = null;

  constructor(config: GatewayConfig) {
    this.config = config;
    this.crypto = new CryptoManager();
    this.token = config.token || randomUUID();
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
        console.log('[Direct] Replacing existing connection (CONFLICT)');
        try {
          this.appWs.send(JSON.stringify({ type: 'error', data: { code: 'CONFLICT', message: 'Connection replaced by new device' } }));
        } catch {
          // ignore send errors on closing socket
        }
        this.appWs.close();
        this.appWs = null;
        this.handshakeState = 'waiting';
        this.seenMessageIds.clear();
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

    ws.on('pong', () => {
    });

    ws.on('close', () => {
      console.log('[Direct] App disconnected');
      this.appWs = null;
      this.handshakeState = 'waiting';
      this.seenMessageIds.clear();
      if (this.pingTimer) {
        clearInterval(this.pingTimer);
        this.pingTimer = null;
      }
      this.stopSseSubscription();
      this.abortActiveStream();
    });

    ws.on('error', (error) => {
      console.error('[Direct] WebSocket error:', error.message);
    });

    this.pingTimer = setInterval(() => {
      if (ws.readyState === WebSocket.OPEN) {
        ws.ping();
      }
    }, 10000);
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

      if (this.sessionInitDone) {
        console.log('[Direct] Reconnect detected, skipping session init');
        if (this.pendingSyncSeq >= 0) {
          console.log(`[Direct] Processing pending sync (lastSeq=${this.pendingSyncSeq})`);
          this.processSync(this.pendingSyncSeq).catch((e: any) => {
            console.error('[Direct] Sync processing failed:', e.message);
          });
          this.pendingSyncSeq = -1;
        }
      } else {
        this.sendEncryptedMessage({
          type: 'reply',
          id: randomUUID(),
          data: { content: '连接成功，正在加载会话...' },
          timestamp: Date.now()
        });

        this.initializeFirstSession().then(() => {
          this.sessionInitDone = true;
          this.startSseSubscription();
          if (this.pendingSyncSeq >= 0) {
            console.log(`[Direct] Processing pending sync (lastSeq=${this.pendingSyncSeq})`);
            this.processSync(this.pendingSyncSeq);
            this.pendingSyncSeq = -1;
          }
        }).catch((e: any) => {
          console.error('[Direct] Session initialization failed:', e.message);
          this.sendError(`Session initialization failed: ${e.message}`, 'INTERNAL');
        });
      }
    }
  }

  private async initializeFirstSession(): Promise<void> {
    let existing = await this.opencode.listSessions();
    existing = existing.filter(s => !s.time.archived);

    for (const s of existing) {
      if (!this.sessions.get(s.id)) {
        this.sessions.create(s.id, s.title || `Session ${this.sessions.list().length + 1}`);
      }
    }

    const created = await this.opencode.createSession();
    this.sessions.create(created.id, created.title);
    this.sessions.switch(created.id);
    console.log(`[Direct] Created fresh session for app: ${created.title} (${created.id})`);

    await this.pushSessionList();
    const active = this.sessions.getActive();
    if (active) {
      await this.pushHistory(active.id);
    }
  }

  private async pushSessionList(): Promise<void> {
    const active = this.sessions.getActive();
    const activeId = active ? active.id : null;
    this.sendEncryptedMessage({
      type: 'session_list',
      id: randomUUID(),
      data: {
        sessions: this.sessions.list().map(s => ({
          id: s.id,
          name: s.name,
          createdAt: s.createdAt,
          lastActivity: s.lastActivity,
          isActive: s.id === activeId
        }))
      },
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
        data: {
          sessionId,
          messages: recent,
          hasMore: allHistory.length > 20,
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

  private handleSync(message: Message): void {
    const lastSeq = (message.data as any).lastSeq || 0;
    console.log(`[Direct] Sync request: lastSeq=${lastSeq}`);

    if (!this.sessionInitDone) {
      console.log('[Direct] Session not ready, queuing sync');
      this.pendingSyncSeq = lastSeq;
      return;
    }

    this.processSync(lastSeq);
  }

  private async processSync(lastSeq: number): Promise<void> {
    const session = this.sessions.getActive();
    if (!session) {
      console.warn('[Direct] Sync: no active session after init');
      return;
    }

    if (lastSeq === 0) {
      await this.pushSessionList();
      await this.pushHistory(session.id);
    }

    const events = this.offlineBuffer.since(session.id, lastSeq);
    console.log(`[Direct] Replaying ${events.length} offline events for session ${session.id}`);

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

    console.log(`[Direct] user_message received: "${message.data.content?.substring(0, 50)}" session=${session.id}`);
    this.sessions.touch(session.id);

    this.sendEncryptedMessage({
      type: 'message_ack',
      id: randomUUID(),
      data: { id: message.id, status: 'accepted' },
      timestamp: Date.now()
    });

    this.messageQueue.push(message);
    this.processMessageQueue();
  }

  private async processMessageQueue(): Promise<void> {
    if (this.isProcessingMessage) return;
    if (this.messageQueue.length === 0) return;

    const session = this.sessions.getActive();
    if (!session) {
      this.isProcessingMessage = false;
      return;
    }

    this.isProcessingMessage = true;
    const message = this.messageQueue.shift()!;

    try {
      console.log(`[Direct] Processing queued message: "${message.data.content?.substring(0, 30)}"`);
      const thinkingId = `thinking_${Date.now()}`;
      this.sendEncryptedMessage({
        type: 'thinking', id: thinkingId, stream: 'start',
        data: { content: '' }, timestamp: Date.now()
      });

      this.activeStream = {
        sessionId: session.id,
        thinkingId,
        thinkingText: '',
        replyPartId: '',
        replyStarted: false,
        assistantMsgId: null
      };

      await new Promise<void>((resolve, reject) => {
        this.streamResolve = resolve;
        this.streamReject = reject;
        this.opencode.promptAsync(session.id, message.data.content).catch(e => {
          if (this.streamReject) this.streamReject(e);
        });
      });

      console.log('[Direct] prompt_async stream completed');
    } catch (e: any) {
      console.error('[Direct] Failed to send message:', e.message);
      this.sendError(`Failed to send message: ${e.message}`, 'INTERNAL');
    } finally {
      this.activeStream = null;
      this.streamResolve = null;
      this.streamReject = null;
      this.isProcessingMessage = false;
      this.processMessageQueue();
    }
  }

  private startSseSubscription(): void {
    if (this.sseStarted) return;
    this.sseStarted = true;
    console.log('[Direct] Starting opencode SSE subscription');
    this.opencode.subscribeEvents((event) => this.handleSseEvent(event)).catch(e => {
      console.error('[Direct] SSE subscription error:', e.message);
      this.sseStarted = false;
    });
  }

  private stopSseSubscription(): void {
    if (!this.sseStarted) return;
    this.sseStarted = false;
    this.opencode.stopEventSubscription();
    console.log('[Direct] Stopped opencode SSE subscription');
  }

  private abortActiveStream(): void {
    if (this.activeStream) {
      if (this.streamReject) this.streamReject(new Error('connection closed'));
      this.activeStream = null;
      this.streamResolve = null;
      this.streamReject = null;
    }
    this.isProcessingMessage = false;
  }

  private handleSseEvent(event: OpencodeEvent): void {
    const props = event.properties || {};
    const stream = this.activeStream;

    switch (event.type) {
      case 'message.part.updated': {
        const part = props.part as OpencodePart;
        if (!part) break;
        this.handlePartUpdated(part, props.messageID || part.messageID);
        break;
      }
      case 'message.part.delta': {
        if (!stream) break;
        if (props.sessionID && props.sessionID !== stream.sessionId) break;
        this.handlePartDelta(props);
        break;
      }
      case 'session.idle': {
        if (!stream) break;
        if (props.sessionID && props.sessionID !== stream.sessionId) break;
        this.completeActiveStream();
        break;
      }
      default:
        break;
    }
  }

  private handlePartUpdated(part: OpencodePart, assistantMsgId: string): void {
    const stream = this.activeStream;
    if (!stream) return;
    if (part.sessionID && part.sessionID !== stream.sessionId) return;

    switch (part.type) {
      case 'reasoning': {
        const text = part.text || '';
        if (text && text !== stream.thinkingText) {
          stream.thinkingText = text;
          this.sendEncryptedMessage({
            type: 'thinking', id: stream.thinkingId, stream: 'replace',
            data: { content: text }, timestamp: Date.now()
          });
        }
        break;
      }
      case 'text': {
        const text = part.text || '';
        if (!stream.replyPartId) {
          stream.replyPartId = part.id;
          stream.replyStarted = true;
          this.sendEncryptedMessage({
            type: 'reply', id: part.id, stream: 'start',
            data: { content: text }, timestamp: Date.now()
          });
        } else if (stream.replyPartId === part.id && text) {
          this.sendEncryptedMessage({
            type: 'reply', id: part.id, stream: 'replace',
            data: { content: text }, timestamp: Date.now()
          });
        }
        break;
      }
      case 'tool':
        this.sendEncryptedMessage({
          type: 'tool_call',
          id: part.id,
          stream: 'end',
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
          data: { url: `session/${part.sessionID}` },
          timestamp: Date.now()
        });
        break;
      default:
        break;
    }
  }

  private handlePartDelta(props: any): void {
    const stream = this.activeStream;
    if (!stream) return;
    if (!props.partID) return;

    const field = props.field;
    const delta = props.delta || '';
    if (!delta) return;

    if (stream.replyPartId === props.partID) {
      this.sendEncryptedMessage({
        type: 'reply', id: stream.replyPartId, stream: 'append',
        data: { content: delta }, timestamp: Date.now()
      });
    }
  }

  private completeActiveStream(): void {
    const stream = this.activeStream;
    if (!stream) return;

    if (stream.replyPartId && stream.replyStarted) {
      this.sendEncryptedMessage({
        type: 'reply', id: stream.replyPartId, stream: 'end',
        data: { content: '' }, timestamp: Date.now()
      });
      stream.replyStarted = false;
    }

    this.sendEncryptedMessage({
      type: 'thinking', id: stream.thinkingId, stream: 'end',
      data: { content: '' }, timestamp: Date.now()
    });

    const resolve = this.streamResolve;
    this.streamResolve = null;
    this.streamReject = null;
    if (resolve) resolve();
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
      this.offlineBuffer.clearSession(message.data.sessionId);
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

      this.sendEncryptedMessage({
        type: 'session_switch',
        id: randomUUID(),
        data: { sessionId: created.id, name: created.title, isActive: true },
        timestamp: Date.now()
      });
      await this.pushHistory(created.id);
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
        data: { sessionId: session.id, name: session.name, isActive: true },
        timestamp: Date.now()
      });
      await this.pushHistory(session.id);
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

    if (!this.appWs || this.appWs.readyState !== WebSocket.OPEN) {
      console.log(`[Direct] Socket closed, event buffered (type=${message.type}, seq=${message.seq ?? '-'})`);
      return;
    }

    const plaintext = JSON.stringify(message);
    const chunks = this.chunkMessage(plaintext);
    
    for (const chunk of chunks) {
      const encrypted = this.crypto.encrypt(chunk);
      this.appWs.send(JSON.stringify(encrypted));
    }
    console.log(`[Direct] Sent to app: type=${message.type} stream=${message.stream ?? '-'} seq=${message.seq ?? '-'}`);
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
