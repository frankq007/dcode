import { Message, MessageData, QRCodeData, EncryptedMessage } from '../models/index';
import { webSocket } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import { CryptoService } from './CryptoService';

const APP_VERSION = '0.1.0';

interface HandshakeInitMsg {
  type: string;
  publicKey: string;
  nonce: string;
  token: string;
  version: string;
}

interface HandshakeAckMsg {
  type: string;
  publicKey: string;
  nonce: string;
  version: string;
  verify?: EncryptedMessage;
}

interface HandshakeCompleteMsg {
  type: string;
  verify: EncryptedMessage;
}

interface ErrorData {
  code?: string;
  message?: string;
}

interface ServerErrorMsg {
  type: string;
  data: ErrorData;
}

interface ParsedMessage {
  type?: string;
  publicKey?: string;
  nonce?: string;
  version?: string;
  iv?: string;
  ciphertext?: string;
  reason?: string;
  data?: ErrorData;
}

interface ChunkEnvelope {
  type: string;
  messageId: string;
  index: number;
  total: number;
  data: string;
}

interface ChunkBuffer {
  chunks: string[];
  received: Set<number>;
  total: number;
  timer: number;
}

interface RelayRegisterMsg {
  type: string;
  token: string;
  role: string;
  version: string;
  relayKey?: string;
}

export class WebSocketService {
  private ws: webSocket.WebSocket | null = null;
  private crypto: CryptoService = new CryptoService();
  private isConnected: boolean = false;
  private handshakeComplete: boolean = false;
  private handshakeState: 'idle' | 'waiting_ack' | 'waiting_complete' | 'done' = 'idle';

  private appNonce: string = '';
  private gwNonce: string = '';

  private messageListeners: ((message: Message) => void)[] = [];
  private connectionListeners: ((connected: boolean) => void)[] = [];
  private reconnectAttempts: number = 0;
  private maxReconnectAttempts: number = 10;
  private reconnectDelay: number = 1000;
  private maxReconnectDelay: number = 30000;
  private reconnectTimer: number | null = null;
  private lastQrData: QRCodeData | null = null;
  private chunkBuffer: Map<string, ChunkBuffer> = new Map();

  private lastSeq: number = 0;
  private isForeground: boolean = true;
  private heartbeatTimer: number | null = null;
  private heartbeatTimeoutTimer: number | null = null;
  private readonly HEARTBEAT_INTERVAL_FOREGROUND: number = 10000;
  private readonly HEARTBEAT_INTERVAL_BACKGROUND: number = 120000;
  private readonly HEARTBEAT_TIMEOUT: number = 20000;
  private readonly PAIRING_TIMEOUT: number = 30000;
  private readonly MAX_MESSAGE_SIZE: number = 1048576;
  private readonly CHUNK_REASSEMBLY_TIMEOUT: number = 30000;
  private relayPairingTimeoutTimer: number | null = null;

  async connect(qrData: QRCodeData): Promise<void> {
    if (qrData.expiresAt && qrData.expiresAt > 0 && Date.now() > qrData.expiresAt) {
      throw new Error('二维码已过期，请刷新');
    }

    if (this.isConnected && this.handshakeComplete) {
      console.log('[WebSocket] Already connected, skipping connect');
      return;
    }

    const isReconnect = this.lastQrData !== null;
    this.lastQrData = qrData;
    this.reconnectAttempts = 0;
    if (!isReconnect) {
      this.lastSeq = 0;
    }
    await this.doConnect(qrData);
  }

  private async doConnect(qrData: QRCodeData): Promise<void> {
    const url = qrData.mode === 'relay' && qrData.relayUrl
      ? qrData.relayUrl
      : `ws://${qrData.host || ''}:${qrData.port || 0}`;

    console.log(`[WebSocket] Connecting to ${url}`);

    try {
      this.ws = webSocket.createWebSocket();

      this.ws.on('open', () => {
        console.log('[WebSocket] Connection opened');
        this.isConnected = true;
        this.reconnectAttempts = 0;
        this.reconnectDelay = 1000;
        if (qrData.mode === 'relay') {
          this.startRelayPairing(qrData);
        } else {
          this.startHandshake(qrData);
        }
      });

      this.ws.on('message', (_err: Error, value: string | ArrayBuffer) => {
        this.handleRawMessage(value);
      });

      this.ws.on('close', () => {
        console.log('[WebSocket] Connection closed');
        this.isConnected = false;
        this.handshakeComplete = false;
        this.handshakeState = 'idle';
        if (this.relayPairingTimeoutTimer) {
          clearTimeout(this.relayPairingTimeoutTimer);
          this.relayPairingTimeoutTimer = null;
        }
        this.stopHeartbeat();
        this.clearChunkBuffer();
        this.notifyConnectionListeners(false);
        this.attemptReconnect();
      });

      this.ws.on('error', (error: Error) => {
        console.error('[WebSocket] Error:', error.message);
      });

      this.ws.connect(url, (err: Error) => {
        if (err) {
          console.error('[WebSocket] Connect failed:', err.message);
        }
      });
    } catch (e) {
      console.error('[WebSocket] Connection error:', e);
    }
  }

  private startRelayPairing(qrData: QRCodeData): void {
    const registerMsg: RelayRegisterMsg = {
      type: 'register',
      token: qrData.token,
      role: 'app',
      version: APP_VERSION,
      relayKey: qrData.relayKey
    };
    this.ws?.send(JSON.stringify(registerMsg));
    console.log(`[WebSocket] Sent relay register (token=${qrData.token.substring(0, 8)}...)`);

    this.relayPairingTimeoutTimer = setTimeout(() => {
      this.relayPairingTimeoutTimer = null;
      console.error('[WebSocket] Relay pairing timeout');
      const errorMsg: Message = {
        type: 'error',
        id: '',
        data: { message: '配对超时，请确认网关已启动并刷新二维码重试', code: 'PAIRING_TIMEOUT' },
        timestamp: Date.now()
      };
      this.notifyMessageListeners(errorMsg);
      this.ws?.close();
    }, this.PAIRING_TIMEOUT);
  }

  private async startHandshake(qrData: QRCodeData): Promise<void> {
    console.log('[WebSocket] Starting ECDH handshake');

    try {
      await this.crypto.generateKeyPair();
      this.appNonce = this.crypto.generateNonce();

      const init: HandshakeInitMsg = {
        type: 'handshake_init',
        publicKey: this.crypto.getPublicKeyBase64(),
        nonce: this.appNonce,
        token: qrData.token,
        version: APP_VERSION
      };

      this.ws?.send(JSON.stringify(init));
      this.handshakeState = 'waiting_ack';
      console.log('[WebSocket] Sent handshake_init');
    } catch (e) {
      console.error('[WebSocket] Handshake start error:', e);
    }
  }

  private async handleRawMessage(data: string | ArrayBuffer): Promise<void> {
    let messageStr: string;
    if (typeof data === 'string') {
      messageStr = data as string;
    } else {
      const textDecoder = new util.TextDecoder();
      messageStr = textDecoder.decodeToString(new Uint8Array(data as ArrayBuffer));
    }

    try {
      const parsed = JSON.parse(messageStr) as ParsedMessage;

      if (this.handshakeState === 'done' && parsed.type === 'chunk') {
        const envelope = JSON.parse(messageStr) as ChunkEnvelope;
        this.handleChunk(envelope);
      } else if (this.handshakeState === 'waiting_ack' && parsed.type === 'handshake_ack') {
        const ack: HandshakeAckMsg = {
          type: parsed.type,
          publicKey: parsed.publicKey || '',
          nonce: parsed.nonce || '',
          version: parsed.version || '',
          verify: parsed.iv && parsed.ciphertext ? { iv: parsed.iv, ciphertext: parsed.ciphertext } : undefined
        };
        await this.handleHandshakeAck(ack);
      } else if (this.handshakeState === 'done' && parsed.iv && parsed.ciphertext) {
        const encrypted: EncryptedMessage = { iv: parsed.iv, ciphertext: parsed.ciphertext };
        await this.handleEncryptedMessage(encrypted);
      } else if (parsed.type === 'error') {
        console.error('[WebSocket] Server error:', parsed.data?.message);
        const errorMsg: Message = {
          type: 'error',
          id: '',
          data: { message: parsed.data?.message || 'Unknown error', code: parsed.data?.code },
          timestamp: Date.now()
        };
        this.notifyMessageListeners(errorMsg);
      } else if (parsed.type === 'paired') {
        console.log('[WebSocket] Paired via relay');
        if (this.relayPairingTimeoutTimer) {
          clearTimeout(this.relayPairingTimeoutTimer);
          this.relayPairingTimeoutTimer = null;
        }
        if (this.handshakeState === 'idle' && this.lastQrData) {
          this.startHandshake(this.lastQrData);
        }
      } else if (parsed.type === 'peer_disconnected') {
        if (parsed.reason === 'replaced') {
          console.log('[WebSocket] Replaced by another device');
          this.reconnectAttempts = this.maxReconnectAttempts;
          const replacedMsg: Message = {
            type: 'error',
            id: '',
            data: { message: '被其他设备取代', code: 'REPLACED' },
            timestamp: Date.now()
          };
          this.notifyMessageListeners(replacedMsg);
        } else {
          console.log('[WebSocket] Peer disconnected');
        }
      } else if (parsed.type === 'waiting') {
        console.log('[WebSocket] Waiting for gateway...');
        const waitingMsg: Message = {
          type: 'error',
          id: '',
          data: { message: '正在等待网关连接...', code: 'WAITING' },
          timestamp: Date.now()
        };
        this.notifyMessageListeners(waitingMsg);
      } else {
        console.warn('[WebSocket] Unhandled message type:', parsed.type);
      }
    } catch (e) {
      console.error('[WebSocket] Parse error:', e);
    }
  }

  private async handleHandshakeAck(ack: HandshakeAckMsg): Promise<void> {
    console.log('[WebSocket] Received handshake_ack');

    this.gwNonce = ack.nonce;

    await this.crypto.deriveSessionKey(ack.publicKey, this.appNonce, this.gwNonce);

    if (ack.verify) {
      const valid = await this.crypto.verifyHandshake(ack.verify, this.appNonce, this.gwNonce, true);
      if (!valid) {
        console.error('[WebSocket] Gateway verify failed - key mismatch');
        this.ws?.close();
        return;
      }
      console.log('[WebSocket] Gateway key verified');
    }

    const myVerify = await this.crypto.createHandshakeVerify(this.appNonce, this.gwNonce, true);

    const complete: HandshakeCompleteMsg = {
      type: 'handshake_complete',
      verify: myVerify
    };

    this.ws?.send(JSON.stringify(complete));
    this.handshakeState = 'done';
    this.handshakeComplete = true;
    this.notifyConnectionListeners(true);
    console.log('[WebSocket] Handshake complete - encrypted channel established');

    this.sendSync();
    this.startHeartbeat();
  }

  private sendSync(): void {
    const syncData: MessageData = { lastSeq: this.lastSeq };
    const syncMessage: Message = {
      type: 'sync',
      id: `sync_${Date.now()}`,
      data: syncData,
      timestamp: Date.now()
    };
    this.sendMessage(syncMessage);
    console.log(`[WebSocket] Sent sync (lastSeq=${this.lastSeq})`);
  }

  private async handleEncryptedMessage(encrypted: EncryptedMessage): Promise<void> {
    try {
      const decrypted = await this.crypto.decrypt(encrypted);
      const message = JSON.parse(decrypted) as Message;
      if (message.type === 'session_switch') {
        this.lastSeq = 0;
        console.log('[WebSocket] Session switched - lastSeq reset');
      }
      if (message.seq && message.seq > this.lastSeq) {
        this.lastSeq = message.seq;
      }
      if (message.type === 'heartbeat') {
        this.clearHeartbeatTimeout();
        return;
      }
      this.notifyMessageListeners(message);
    } catch (e) {
      console.error('[WebSocket] Decrypt error:', e);
    }
  }

  private handleChunk(envelope: ChunkEnvelope): void {
    const messageId: string = envelope.messageId;
    const index: number = envelope.index;
    const total: number = envelope.total;
    const chunkData: string = envelope.data;

    if (!messageId || index < 0 || index >= total || total <= 0) {
      console.warn(`[WebSocket] Invalid chunk index: ${index}/${total}`);
      return;
    }

    let buffer = this.chunkBuffer.get(messageId);
    if (!buffer) {
      const chunks: string[] = new Array(total);
      buffer = { chunks, received: new Set<number>(), total, timer: 0 };
      buffer.timer = setTimeout(() => {
        console.warn(`[WebSocket] Chunk reassembly timeout for messageId: ${messageId}, discarding`);
        this.chunkBuffer.delete(messageId);
      }, this.CHUNK_REASSEMBLY_TIMEOUT);
      this.chunkBuffer.set(messageId, buffer);
    }

    if (buffer.total !== total) {
      console.warn(`[WebSocket] Chunk total mismatch for messageId: ${messageId}`);
      return;
    }

    if (!buffer.received.has(index)) {
      buffer.received.add(index);
    }
    buffer.chunks[index] = chunkData;

    console.log(`[WebSocket] Chunk received: ${buffer.received.size}/${total} for ${messageId}`);

    if (buffer.received.size >= total) {
      clearTimeout(buffer.timer);
      this.chunkBuffer.delete(messageId);
      const reassembled = buffer.chunks.join('');
      console.log(`[WebSocket] All chunks received for ${messageId}, reassembling`);

      try {
        const encrypted = JSON.parse(reassembled) as EncryptedMessage;
        if (encrypted.iv && encrypted.ciphertext) {
          this.handleEncryptedMessage(encrypted);
        } else {
          console.warn('[WebSocket] Reassembled message missing encryption fields');
        }
      } catch (e) {
        console.error('[WebSocket] Failed to parse reassembled chunk:', e);
      }
    }
  }

  async sendMessage(message: Message): Promise<void> {
    if (!this.isConnected || !this.handshakeComplete) {
      console.warn('[WebSocket] Cannot send: not connected or handshake incomplete');
      return;
    }

    try {
      const encrypted = await this.crypto.encrypt(JSON.stringify(message));
      const frame = JSON.stringify(encrypted);

      if (frame.length <= this.MAX_MESSAGE_SIZE) {
        this.ws?.send(frame);
      } else {
        const chunks = this.chunkFrame(frame);
        const messageId = `chunk_${Date.now()}_${Math.floor(Math.random() * 1000000)}`;
        for (let i = 0; i < chunks.length; i++) {
          const envelope: ChunkEnvelope = {
            type: 'chunk',
            messageId,
            index: i,
            total: chunks.length,
            data: chunks[i]
          };
          this.ws?.send(JSON.stringify(envelope));
        }
      }
    } catch (e) {
      console.error('[WebSocket] Send error:', e);
    }
  }

  private chunkFrame(frame: string): string[] {
    const chunks: string[] = [];
    for (let i = 0; i < frame.length; i += this.MAX_MESSAGE_SIZE) {
      chunks.push(frame.substring(i, Math.min(i + this.MAX_MESSAGE_SIZE, frame.length)));
    }
    return chunks;
  }

  private clearChunkBuffer(): void {
    this.chunkBuffer.forEach((buffer: ChunkBuffer) => {
      clearTimeout(buffer.timer);
    });
    this.chunkBuffer.clear();
  }

  disconnect(): void {
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }

    if (this.relayPairingTimeoutTimer) {
      clearTimeout(this.relayPairingTimeoutTimer);
      this.relayPairingTimeoutTimer = null;
    }

    this.stopHeartbeat();
    this.clearChunkBuffer();
    this.lastQrData = null;
    this.handshakeState = 'idle';
    this.handshakeComplete = false;

    if (this.ws) {
      try {
        this.ws.close();
      } catch (e) {
        console.error('[WebSocket] Close error:', e);
      }
      this.ws = null;
    }
  }

  private startHeartbeat(): void {
    this.stopHeartbeat();
    const interval = this.isForeground
      ? this.HEARTBEAT_INTERVAL_FOREGROUND
      : this.HEARTBEAT_INTERVAL_BACKGROUND;

    this.heartbeatTimer = setInterval(() => {
      this.sendHeartbeat();
    }, interval);
    console.log(`[WebSocket] Heartbeat started (${interval}ms)`);
  }

  private stopHeartbeat(): void {
    if (this.heartbeatTimer) {
      clearInterval(this.heartbeatTimer);
      this.heartbeatTimer = null;
    }
    this.clearHeartbeatTimeout();
  }

  private sendHeartbeat(): void {
    if (!this.isConnected || !this.handshakeComplete) return;

    const hbData: MessageData = {};
    const heartbeat: Message = {
      type: 'heartbeat',
      id: `hb_${Date.now()}`,
      data: hbData,
      timestamp: Date.now()
    };
    this.sendMessage(heartbeat);

    this.clearHeartbeatTimeout();
    this.heartbeatTimeoutTimer = setTimeout(() => {
      console.warn('[WebSocket] Heartbeat timeout - forcing reconnect');
      if (this.ws) {
        try {
          this.ws.close();
        } catch (e) {
          console.error('[WebSocket] Force close error:', e);
        }
      }
    }, this.HEARTBEAT_TIMEOUT);
  }

  private clearHeartbeatTimeout(): void {
    if (this.heartbeatTimeoutTimer) {
      clearTimeout(this.heartbeatTimeoutTimer);
      this.heartbeatTimeoutTimer = null;
    }
  }

  setForeground(): void {
    if (!this.isForeground) {
      this.isForeground = true;
      if (this.handshakeComplete) {
        this.startHeartbeat();
      }
      console.log('[WebSocket] Foreground - heartbeat resumed');
    }
  }

  setBackground(): void {
    if (this.isForeground) {
      this.isForeground = false;
      if (this.handshakeComplete) {
        this.startHeartbeat();
      }
      console.log('[WebSocket] Background - heartbeat slowed');
    }
  }

  private attemptReconnect(): void {
    if (this.reconnectAttempts >= this.maxReconnectAttempts) {
      console.log('[WebSocket] Max reconnect attempts reached');
      return;
    }

    if (!this.lastQrData) return;

    this.reconnectAttempts++;
    const delay = Math.min(this.reconnectDelay * Math.pow(2, this.reconnectAttempts - 1), this.maxReconnectDelay);

    console.log(`[WebSocket] Reconnecting in ${delay}ms (attempt ${this.reconnectAttempts}/${this.maxReconnectAttempts})`);

    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
    }

    this.reconnectTimer = setTimeout(async () => {
      if (this.lastQrData) {
        await this.doConnect(this.lastQrData);
      }
    }, delay);
  }

  onMessage(listener: (message: Message) => void): void {
    this.messageListeners.push(listener);
  }

  onConnectionChange(listener: (connected: boolean) => void): void {
    this.connectionListeners.push(listener);
  }

  private notifyMessageListeners(message: Message): void {
    this.messageListeners.forEach(listener => listener(message));
  }

  private notifyConnectionListeners(connected: boolean): void {
    this.connectionListeners.forEach(listener => listener(connected));
  }
}

export const webSocketService = new WebSocketService();
