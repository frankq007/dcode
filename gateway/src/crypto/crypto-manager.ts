import { generateKeyPairSync, createHash, createCipheriv, createDecipheriv, randomBytes, KeyObject, diffieHellman as ecdhDiffieHellman } from 'crypto';

export interface X25519KeyPair {
  publicKey: Buffer;
  privateKey: KeyObject;
  publicKeyObj: KeyObject;
}

export interface EncryptedMessage {
  iv: string;
  ciphertext: string;
}

export class CryptoManager {
  private keyPair: X25519KeyPair;
  private sessionKey: Buffer | null = null;

  constructor() {
    const { publicKey, privateKey } = generateKeyPairSync('x25519');
    const publicKeyDer = publicKey.export({ type: 'spki', format: 'der' });
    const rawPublicKey = publicKeyDer.subarray(publicKeyDer.length - 32);
    
    this.keyPair = {
      publicKey: rawPublicKey,
      privateKey,
      publicKeyObj: publicKey
    };
  }

  getPublicKeyBase64(): string {
    return this.keyPair.publicKey.toString('base64');
  }

  deriveSessionKey(peerPublicKeyBase64: string, nonce1: string, nonce2: string): void {
    const peerPublicKeyDer = this.importRawX25519PublicKey(peerPublicKeyBase64);
    
    const sharedSecret = ecdhDiffieHellman({
      privateKey: this.keyPair.privateKey,
      publicKey: peerPublicKeyDer
    });

    const nonceBuffer = Buffer.concat([
      Buffer.from(nonce1, 'base64'),
      Buffer.from(nonce2, 'base64')
    ]);

    this.sessionKey = createHash('sha256')
      .update(sharedSecret)
      .update(nonceBuffer)
      .digest();
  }

  encrypt(plaintext: string): EncryptedMessage {
    if (!this.sessionKey) {
      throw new Error('Session key not derived');
    }

    const iv = randomBytes(12);
    const cipher = createCipheriv('aes-256-gcm', this.sessionKey, iv);
    
    const encrypted = Buffer.concat([
      cipher.update(plaintext, 'utf8'),
      cipher.final()
    ]);
    
    const authTag = cipher.getAuthTag();
    const ciphertext = Buffer.concat([encrypted, authTag]);

    return {
      iv: iv.toString('base64'),
      ciphertext: ciphertext.toString('base64')
    };
  }

  decrypt(encrypted: EncryptedMessage): string {
    if (!this.sessionKey) {
      throw new Error('Session key not derived');
    }

    const iv = Buffer.from(encrypted.iv, 'base64');
    const ciphertextBuffer = Buffer.from(encrypted.ciphertext, 'base64');
    
    const authTag = ciphertextBuffer.subarray(-16);
    const encryptedData = ciphertextBuffer.subarray(0, -16);

    const decipher = createDecipheriv('aes-256-gcm', this.sessionKey, iv);
    decipher.setAuthTag(authTag);

    const decrypted = Buffer.concat([
      decipher.update(encryptedData),
      decipher.final()
    ]);

    return decrypted.toString('utf8');
  }

  private importRawX25519PublicKey(publicKeyBase64: string): KeyObject {
    const publicKey = Buffer.from(publicKeyBase64, 'base64');
    const spkiHeader = Buffer.from('302a300506032b656e032100', 'hex');
    const derPublicKey = Buffer.concat([spkiHeader, publicKey]);
    
    const { createPublicKey } = require('crypto');
    return createPublicKey({
      key: derPublicKey,
      format: 'der',
      type: 'spki'
    });
  }
}
