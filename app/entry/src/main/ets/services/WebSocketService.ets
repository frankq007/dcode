import { Connection, Message, QRCodeData } from '../models/index';
import { webSocket, WebSocket as ArkWebSocket } from '@kit.NetworkKit';

export class WebSocketService {
  private ws: ArkWebSocket | null = null;
  private isConnected: boolean = false;
  private handshakeComplete: boolean = false;
  private sessionKey: ArrayBuffer | null = null;
  
  private messageListeners: ((message: Message) => void)[] = [];
  private connectionListeners: ((connected: boolean) => void)[] = [];

  connect(qrData: QRCodeData): void {
    const url = `ws://${qrData.host}:${qrData.port}`;
    console.log(`[WebSocket] Connecting to ${url}`);
    
    this.ws = webSocket.createWebSocket();
    
    this.ws.on('open', (err: Error, value: Object) => {
      console.log('[WebSocket] Connection opened');
      this.isConnected = true;
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
      this.sessionKey = null;
      this.notifyConnectionListeners(false);
    });
    
    this.ws.on('error', (err: Error, value: Object) => {
      console.error('[WebSocket] Error:', err.message);
      this.notifyConnectionListeners(false);
    });
    
    this.ws.connect(url, (err: Error, value: Object) => {
      if (err) {
        console.error('[WebSocket] Connect failed:', err.message);
      }
    });
  }

  private startHandshake(qrData: QRCodeData): void {
    console.log('[WebSocket] Starting handshake');
    
    const handshakeInit = {
      type: 'handshake_init',
      publicKey: this.generatePublicKey(),
      nonce: this.generateNonce(),
      version: '0.1.0'
    };
    
    this.ws?.send(JSON.stringify(handshakeInit));
  }

  private handleMessage(data: string | ArrayBuffer): void {
    const message = typeof data === 'string' ? data : new TextDecoder().decode(data as ArrayBuffer);
    
    if (!this.handshakeComplete) {
      this.handleHandshakeMessage(message);
    } else {
      this.handleEncryptedMessage(message);
    }
  }

  private handleHandshakeMessage(message: string): void {
    try {
      const parsed = JSON.parse(message);
      
      if (parsed.type === 'handshake_ack') {
        console.log('[WebSocket] Handshake ACK received');
        this.deriveSessionKey(parsed.publicKey, parsed.nonce);
        
        const handshakeComplete = {
          type: 'handshake_complete',
          nonce: this.generateNonce()
        };
        
        this.ws?.send(JSON.stringify(handshakeComplete));
        this.handshakeComplete = true;
        console.log('[WebSocket] Handshake complete');
      }
    } catch (e) {
      console.error('[WebSocket] Handshake parse error:', e);
    }
  }

  private handleEncryptedMessage(encryptedData: string): void {
    try {
      const encrypted = JSON.parse(encryptedData);
      const decrypted = this.decrypt(encrypted);
      const message: Message = JSON.parse(decrypted);
      this.notifyMessageListeners(message);
    } catch (e) {
      console.error('[WebSocket] Decrypt/parse error:', e);
    }
  }

  sendMessage(message: Message): void {
    if (!this.isConnected || !this.handshakeComplete) {
      console.warn('[WebSocket] Cannot send: not connected or handshake incomplete');
      return;
    }
    
    const plaintext = JSON.stringify(message);
    const encrypted = this.encrypt(plaintext);
    this.ws?.send(JSON.stringify(encrypted));
  }

  disconnect(): void {
    if (this.ws) {
      this.ws.close();
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

  private generatePublicKey(): string {
    return 'MOCK_PUBLIC_KEY_BASE64';
  }

  private generateNonce(): string {
    const array = new Uint8Array(16);
    for (let i = 0; i < 16; i++) {
      array[i] = Math.floor(Math.random() * 256);
    }
    return this.arrayBufferToBase64(array.buffer);
  }

  private deriveSessionKey(peerPublicKey: string, nonce: string): void {
    console.log('[WebSocket] Session key derived (mock)');
  }

  private encrypt(plaintext: string): any {
    return {
      iv: this.generateNonce(),
      ciphertext: this.arrayBufferToBase64(new TextEncoder().encode(plaintext).buffer)
    };
  }

  private decrypt(encrypted: any): string {
    return new TextDecoder().decode(this.base64ToArrayBuffer(encrypted.ciphertext));
  }

  private arrayBufferToBase64(buffer: ArrayBuffer): string {
    const bytes = new Uint8Array(buffer);
    let binary = '';
    for (let i = 0; i < bytes.length; i++) {
      binary += String.fromCharCode(bytes[i]);
    }
    return btoa(binary);
  }

  private base64ToArrayBuffer(base64: string): ArrayBuffer {
    const binary = atob(base64);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) {
      bytes[i] = binary.charCodeAt(i);
    }
    return bytes.buffer;
  }
}

export const webSocketService = new WebSocketService();
