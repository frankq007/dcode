import { Message, QRCodeData } from '../models/index';
import { webSocket } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';

interface HandshakeInit {
  type: string;
  token: string;
  version: string;
}

export class WebSocketService {
  private ws: webSocket.WebSocket | null = null;
  private isConnected: boolean = false;
  private handshakeComplete: boolean = false;

  private messageListeners: ((message: Message) => void)[] = [];
  private connectionListeners: ((connected: boolean) => void)[] = [];
  private reconnectAttempts: number = 0;
  private maxReconnectAttempts: number = 10;
  private reconnectDelay: number = 1000;
  private maxReconnectDelay: number = 30000;
  private reconnectTimer: number | null = null;
  private lastQrData: QRCodeData | null = null;

  async connect(qrData: QRCodeData): Promise<void> {
    this.lastQrData = qrData;
    this.reconnectAttempts = 0;
    await this.doConnect(qrData);
  }

  private async doConnect(qrData: QRCodeData): Promise<void> {
    const url = qrData.mode === 'relay' && qrData.relayUrl
      ? qrData.relayUrl
      : `ws://${qrData.host}:${qrData.port}`;

    console.log(`[WebSocket] Connecting to ${url}`);

    try {
      this.ws = webSocket.createWebSocket();

      this.ws.on('open', (err: Error, value: Object) => {
        console.log('[WebSocket] Connection opened');
        this.isConnected = true;
        this.reconnectAttempts = 0;
        this.reconnectDelay = 1000;
        this.notifyConnectionListeners(true);
        this.startHandshake(qrData);
      });

      this.ws.on('message', (err: Error, value: string | ArrayBuffer) => {
        this.handleMessage(value);
      });

      this.ws.on('close', (err: Error, value: Object) => {
        console.log('[WebSocket] Connection closed');
        this.isConnected = false;
        this.handshakeComplete = false;
        this.notifyConnectionListeners(false);
        this.attemptReconnect();
      });

      this.ws.connect(url, (err: Error, value: Object) => {
        if (err) {
          console.error('[WebSocket] Connect failed:', err.message);
        }
      });
    } catch (e) {
      console.error('[WebSocket] Connection error:', e);
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

  private startHandshake(qrData: QRCodeData): void {
    console.log('[WebSocket] Starting handshake');

    try {
      const handshakeInit: HandshakeInit = {
        type: 'handshake_init',
        token: qrData.token,
        version: '0.1.0'
      };

      this.ws?.send(JSON.stringify(handshakeInit));
      this.handshakeComplete = true;
      console.log('[WebSocket] Handshake complete');
    } catch (e) {
      console.error('[WebSocket] Handshake start error:', e);
    }
  }

  private handleMessage(data: string | ArrayBuffer): void {
    let messageStr: string;
    if (typeof data === 'string') {
      messageStr = data as string;
    } else {
      const textDecoder = new util.TextDecoder('utf-8');
      const result = textDecoder.decodeWithStream(new Uint8Array(data as ArrayBuffer));
      messageStr = result;
    }

    try {
      const message: Message = JSON.parse(messageStr) as Message;
      this.notifyMessageListeners(message);
    } catch (e) {
      console.error('[WebSocket] Parse error:', e);
    }
  }

  sendMessage(message: Message): void {
    if (!this.isConnected || !this.handshakeComplete) {
      console.warn('[WebSocket] Cannot send: not connected or handshake incomplete');
      return;
    }

    try {
      const jsonStr = JSON.stringify(message);
      this.ws?.send(jsonStr);
    } catch (e) {
      console.error('[WebSocket] Send error:', e);
    }
  }

  disconnect(): void {
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }

    this.lastQrData = null;

    if (this.ws) {
      try {
        this.ws.close();
      } catch (e) {
        console.error('[WebSocket] Close error:', e);
      }
      this.ws = null;
    }
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