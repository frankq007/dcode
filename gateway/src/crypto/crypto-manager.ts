import {
  generateKeyPairSync, hkdfSync, createCipheriv, createDecipheriv,
  randomBytes, KeyObject, diffieHellman as ecdhDiffieHellman, createPublicKey
} from 'crypto';

export interface EncryptedMessage {
  iv: string;
  ciphertext: string;
}

const MAGIC = 'DCODE-HANDSHAKE-OK';
const INFO_LABEL = Buffer.from('dcode-session-key', 'utf8');
const ZERO_IV = Buffer.alloc(12, 0);

export class CryptoManager {
  private privateKey: KeyObject;
  private publicKeyRaw: Buffer;
  private sessionKey: Buffer | null = null;

  constructor() {
    const { publicKey, privateKey } = generateKeyPairSync('x25519');
    this.privateKey = privateKey;
    const der = publicKey.export({ type: 'spki', format: 'der' });
    this.publicKeyRaw = der.subarray(der.length - 32);
  }

  getPublicKeyBase64(): string {
    return this.publicKeyRaw.toString('base64');
  }

  deriveSessionKey(peerPublicKeyBase64: string, appNonceB64: string, gwNonceB64: string): void {
    const peerKey = this.importRawX25519PublicKey(peerPublicKeyBase64);
    const sharedSecret = ecdhDiffieHellman({
      privateKey: this.privateKey,
      publicKey: peerKey
    });

    const appNonce = Buffer.from(appNonceB64, 'base64');
    const gwNonce = Buffer.from(gwNonceB64, 'base64');
    const info = Buffer.concat([INFO_LABEL, appNonce, gwNonce]);

    this.sessionKey = Buffer.from(hkdfSync('sha256', sharedSecret, Buffer.alloc(0), info, 32));
  }

  createHandshakeVerify(appNonceB64: string, gwNonceB64: string, isFirstPartyGateway: boolean): EncryptedMessage {
    if (!this.sessionKey) throw new Error('Session key not derived');

    const appNonce = Buffer.from(appNonceB64, 'base64');
    const gwNonce = Buffer.from(gwNonceB64, 'base64');

    const plaintext = isFirstPartyGateway
      ? Buffer.concat([Buffer.from(MAGIC, 'utf8'), gwNonce, appNonce])
      : Buffer.concat([Buffer.from(MAGIC, 'utf8'), appNonce, gwNonce]);

    const cipher = createCipheriv('aes-256-gcm', this.sessionKey, ZERO_IV);
    const encrypted = Buffer.concat([cipher.update(plaintext), cipher.final()]);
    const authTag = cipher.getAuthTag();

    return {
      iv: ZERO_IV.toString('base64'),
      ciphertext: Buffer.concat([encrypted, authTag]).toString('base64')
    };
  }

  verifyHandshake(verify: EncryptedMessage, appNonceB64: string, gwNonceB64: string, isFirstPartyGateway: boolean): boolean {
    if (!this.sessionKey) throw new Error('Session key not derived');

    try {
      const iv = Buffer.from(verify.iv, 'base64');
      const data = Buffer.from(verify.ciphertext, 'base64');
      const authTag = data.subarray(-16);
      const ciphertext = data.subarray(0, -16);

      const decipher = createDecipheriv('aes-256-gcm', this.sessionKey, iv);
      decipher.setAuthTag(authTag);
      const decrypted = Buffer.concat([decipher.update(ciphertext), decipher.final()]);

      const appNonce = Buffer.from(appNonceB64, 'base64');
      const gwNonce = Buffer.from(gwNonceB64, 'base64');
      const expected = isFirstPartyGateway
        ? Buffer.concat([Buffer.from(MAGIC, 'utf8'), gwNonce, appNonce])
        : Buffer.concat([Buffer.from(MAGIC, 'utf8'), appNonce, gwNonce]);

      return decrypted.equals(expected);
    } catch {
      return false;
    }
  }

  encrypt(plaintext: string): EncryptedMessage {
    if (!this.sessionKey) throw new Error('Session key not derived');

    const iv = randomBytes(12);
    const cipher = createCipheriv('aes-256-gcm', this.sessionKey, iv);
    const encrypted = Buffer.concat([cipher.update(plaintext, 'utf8'), cipher.final()]);
    const authTag = cipher.getAuthTag();

    return {
      iv: iv.toString('base64'),
      ciphertext: Buffer.concat([encrypted, authTag]).toString('base64')
    };
  }

  decrypt(encrypted: EncryptedMessage): string {
    if (!this.sessionKey) throw new Error('Session key not derived');

    const iv = Buffer.from(encrypted.iv, 'base64');
    const data = Buffer.from(encrypted.ciphertext, 'base64');
    const authTag = data.subarray(-16);
    const ciphertext = data.subarray(0, -16);

    const decipher = createDecipheriv('aes-256-gcm', this.sessionKey, iv);
    decipher.setAuthTag(authTag);

    const decrypted = Buffer.concat([decipher.update(ciphertext), decipher.final()]);
    return decrypted.toString('utf8');
  }

  private importRawX25519PublicKey(publicKeyBase64: string): KeyObject {
    const rawKey = Buffer.from(publicKeyBase64, 'base64');
    const spkiHeader = Buffer.from('302a300506032b656e032100', 'hex');
    const derKey = Buffer.concat([spkiHeader, rawKey]);
    return createPublicKey({ key: derKey, format: 'der', type: 'spki' });
  }
}
