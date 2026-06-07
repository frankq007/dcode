import { Connection, Message, QRCodeData } from '../models/index';
import { webSocket, WebSocket as ArkWebSocket } from '@kit.NetworkKit';
import { cryptoFramework, x509 } from '@kit.CryptoArchitectureKit';

export class WebSocketService {
  private ws: ArkWebSocket | null = null;
  private isConnected: boolean = false;
  private handshakeComplete: boolean = false;
  private sessionKey: ArrayBuffer | null = null;
  private privateKey: cryptoFramework.AsymmetricKey | null = null;
  private publicKey: cryptoFramework.AsymmetricKey | null = null;
  
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
        this.sessionKey = null;
        this.notifyConnectionListeners(false);
        this.attemptReconnect();
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

  private async startHandshake(qrData: QRCodeData): Promise<void> {
    console.log('[WebSocket] Starting handshake');
    
    try {
      await this.generateKeyPair();
      
      const nonce = this.generateNonce();
      const publicKeyBase64 = this.exportPublicKeyBase64();
      
      const handshakeInit = {
        type: 'handshake_init',
        publicKey: publicKeyBase64,
        nonce: nonce,
        version: '0.1.0'
      };
      
      this.ws?.send(JSON.stringify(handshakeInit));
    } catch (e) {
      console.error('[WebSocket] Handshake start error:', e);
    }
  }

  private async generateKeyPair(): Promise<void> {
    const x25519Params = cryptoFramework.createAsymmetricKeyGeneratorSpec('X25519');
    const keyGen = cryptoFramework.createAsymmetricKeyGenerator(x25519Params);
    const keyPair = await keyGen.generateKeyPair();
    
    this.privateKey = keyPair.priKey;
    this.publicKey = keyPair.pubKey;
    
    console.log('[WebSocket] X25519 key pair generated');
  }

  private exportPublicKeyBase64(): string {
    if (!this.publicKey) return '';
    
    const publicKeyBlob = this.publicKey.getEncodedKeyData();
    return this.arrayBufferToBase64(publicKeyBlob.data);
  }

  private handleMessage(data: string | ArrayBuffer): void {
    const message = typeof data === 'string' ? data : new TextDecoder().decode(data as ArrayBuffer);
    
    if (!this.handshakeComplete) {
      this.handleHandshakeMessage(message);
    } else {
      this.handleEncryptedMessage(message);
    }
  }

  private async handleHandshakeMessage(message: string): Promise<void> {
    try {
      const parsed = JSON.parse(message);
      
      if (parsed.type === 'handshake_ack') {
        console.log('[WebSocket] Handshake ACK received');
        await this.deriveSessionKey(parsed.publicKey, parsed.nonce);
        
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

  private async deriveSessionKey(peerPublicKeyBase64: string, peerNonce: string): Promise<void> {
    if (!this.privateKey) return;

    try {
      const peerPublicKeyBlob = {
        data: this.base64ToArrayBuffer(peerPublicKeyBase64),
        alg: 'X25519',
        encodeType: cryptoFramework.EncodingType.DER
      };

      const x25519Params = cryptoFramework.createAsymmetricKeyGeneratorSpec('X25519');
      const keyGen = cryptoFramework.createAsymmetricKeyGenerator(x25519Params);
      const peerPublicKey = await keyGen.convertKey(peerPublicKeyBlob, null);

      const x25519AgreeSpec = cryptoFramework.createAsymmetricKeyAgreeSpec('X25519');
      x25519AgreeSpec.publicKey = peerPublicKey;

      const keyAgree = cryptoFramework.createAsymmetricKeyAgree('X25519');
      const sharedSecret = await keyAgree.doFinal(this.privateKey, x25519AgreeSpec);

      const localNonce = this.generateNonce();
      const nonceBuffer = new Uint8Array([
        ...new Uint8Array(this.base64ToArrayBuffer(peerNonce)),
        ...new Uint8Array(this.base64ToArrayBuffer(localNonce))
      ]);

      const hashSpec = cryptoFramework.createHashSpec('SHA256');
      const hash = cryptoFramework.createHash(hashSpec);
      await hash.update(sharedSecret.data);
      await hash.update(nonceBuffer.buffer);
      this.sessionKey = await hash.digest();

      console.log('[WebSocket] Session key derived');
    } catch (e) {
      console.error('[WebSocket] Key derivation error:', e);
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
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }
    
    this.lastQrData = null;
    
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

  private generateNonce(): string {
    const array = new Uint8Array(16);
    for (let i = 0; i < 16; i++) {
      array[i] = Math.floor(Math.random() * 256);
    }
    return this.arrayBufferToBase64(array.buffer);
  }

  private encrypt(plaintext: string): any {
    if (!this.sessionKey) {
      throw new Error('Session key not derived');
    }

    const iv = new Uint8Array(12);
    for (let i = 0; i < 12; i++) {
      iv[i] = Math.floor(Math.random() * 256);
    }

    const encoder = new TextEncoder();
    const data = encoder.encode(plaintext);

    const cipherSpec = cryptoFramework.createCipherSpec('AES256|GCM');
    cipherSpec.iv = iv.buffer;

    const cipher = cryptoFramework.createCipher(cipherSpec);
    const encrypted = cipher.doFinal(this.sessionKey, data.buffer);

    return {
      iv: this.arrayBufferToBase64(iv.buffer),
      ciphertext: this.arrayBufferToBase64(encrypted.data)
    };
  }

  private decrypt(encrypted: any): string {
    if (!this.sessionKey) {
      throw new Error('Session key not derived');
    }

    const iv = new Uint8Array(this.base64ToArrayBuffer(encrypted.iv));
    const ciphertext = this.base64ToArrayBuffer(encrypted.ciphertext);

    const cipherSpec = cryptoFramework.createCipherSpec('AES256|GCM');
    cipherSpec.iv = iv.buffer;

    const cipher = cryptoFramework.createCipher(cipherSpec);
    const decrypted = cipher.doFinal(this.sessionKey, ciphertext);

    const decoder = new TextDecoder();
    return decoder.decode(decrypted.data);
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
