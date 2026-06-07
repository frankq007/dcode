import WebSocket, { RawData } from 'ws';
import { randomUUID, randomBytes } from 'crypto';
import { CryptoManager } from '../crypto/crypto-manager';
import { OpencodeClient, OpencodeEvent } from '../opencode/opencode-client';
import { SessionManager } from '../session/session-manager';
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
  private sseControllers: Map<string, AbortController> = new Map();
  private seenMessageIds: Set<string> = new Set();

  constructor(config: GatewayConfig) {
    this.config = config;
    this.crypto = new CryptoManager();
    this.token = randomUUID();
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
      
      const gatewayNonce = randomBytes(16).toString('base64');
      
      const ack: HandshakeMessage = {
        type: 'handshake_ack',
        publicKey: this.crypto.getPublicKeyBase64(),
        nonce: gatewayNonce,
        version: this.config.version
      };
      
      this.ws?.send(JSON.stringify(ack));
      this.handshakeState = 'step1';
      
      (this as any)._appNonce = msg.nonce;
      (this as any)._appPublicKey = msg.publicKey;
      (this as any)._gatewayNonce = gatewayNonce;
    } else if (this.handshakeState === 'step1' && msg.type === 'handshake_complete') {
      const appNonce = (this as any)._appNonce;
      const gatewayNonce = (this as any)._gatewayNonce;
      const appPublicKey = (this as any)._appPublicKey;
      
      this.crypto.deriveSessionKey(appPublicKey, appNonce, gatewayNonce);
      this.handshakeState = 'complete';
      
      console.log('[Relay] Handshake complete: session key derived');
      
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

  private handleEncryptedMessage(encrypted: any): void {
    try {
      const decrypted = this.crypto.decrypt(encrypted);
      const message = JSON.parse(decrypted);
      this.processDecryptedMessage(message);
    } catch (e: any) {
      console.error('[Relay] Decryption/parse error:', e.message);
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
    if (!this.ws || this.ws.readyState !== WebSocket.OPEN) return;
    if (this.handshakeState !== 'complete') return;
    
    const plaintext = JSON.stringify(message);
    const encrypted = this.crypto.encrypt(plaintext);
    this.ws.send(JSON.stringify(encrypted));
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

  private cleanupConnection(): void {
    this.handshakeState = 'waiting';
    this.seenMessageIds.clear();
    this.cleanupSSEConnections();
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
    this.cleanupSSEConnections();
    if (this.ws) {
      this.ws.close();
    }
    console.log('[Relay] Client stopped');
  }
}
