import { describe, it, expect } from 'vitest';
import { CryptoManager } from './crypto-manager';
import { randomBytes } from 'crypto';

describe('CryptoManager', () => {
  it('should generate X25519 key pair', () => {
    const manager = new CryptoManager();
    const publicKey = manager.getPublicKeyBase64();
    expect(publicKey).toBeDefined();
    expect(typeof publicKey).toBe('string');
    expect(publicKey.length).toBeGreaterThan(0);
  });

  it('should derive matching session keys via HKDF-SHA256', () => {
    const gateway = new CryptoManager();
    const app = new CryptoManager();

    const appNonce = randomBytes(16).toString('base64');
    const gwNonce = randomBytes(16).toString('base64');

    gateway.deriveSessionKey(app.getPublicKeyBase64(), appNonce, gwNonce);
    app.deriveSessionKey(gateway.getPublicKeyBase64(), appNonce, gwNonce);

    const plaintext = 'Hello, encrypted world!';
    const encrypted = gateway.encrypt(plaintext);
    const decrypted = app.decrypt(encrypted);

    expect(decrypted).toBe(plaintext);
  });

  it('should encrypt and decrypt messages correctly', () => {
    const m1 = new CryptoManager();
    const m2 = new CryptoManager();

    const appNonce = randomBytes(16).toString('base64');
    const gwNonce = randomBytes(16).toString('base64');

    m1.deriveSessionKey(m2.getPublicKeyBase64(), appNonce, gwNonce);
    m2.deriveSessionKey(m1.getPublicKeyBase64(), appNonce, gwNonce);

    const testMessages = [
      'Short message',
      'A longer message with special characters: !@#$%^&*()',
      JSON.stringify({ type: 'test', data: { nested: 'object' } }),
      '中文测试消息'
    ];

    for (const msg of testMessages) {
      const encrypted = m1.encrypt(msg);
      const decrypted = m2.decrypt(encrypted);
      expect(decrypted).toBe(msg);
    }
  });

  it('should create and verify handshake verify (bidirectional)', () => {
    const gateway = new CryptoManager();
    const app = new CryptoManager();

    const appNonce = randomBytes(16).toString('base64');
    const gwNonce = randomBytes(16).toString('base64');

    gateway.deriveSessionKey(app.getPublicKeyBase64(), appNonce, gwNonce);
    app.deriveSessionKey(gateway.getPublicKeyBase64(), appNonce, gwNonce);

    // Gateway creates verify for App to check (Gateway proves it has the key)
    const gwVerify = gateway.createHandshakeVerify(appNonce, gwNonce, true);
    expect(app.verifyHandshake(gwVerify, appNonce, gwNonce, true)).toBe(true);

    // App creates verify for Gateway to check (App proves it has the key)
    const appVerify = app.createHandshakeVerify(appNonce, gwNonce, false);
    expect(gateway.verifyHandshake(appVerify, appNonce, gwNonce, false)).toBe(true);
  });

  it('should reject handshake verify with wrong key', () => {
    const gateway = new CryptoManager();
    const app = new CryptoManager();
    const attacker = new CryptoManager();

    const appNonce = randomBytes(16).toString('base64');
    const gwNonce = randomBytes(16).toString('base64');

    gateway.deriveSessionKey(app.getPublicKeyBase64(), appNonce, gwNonce);
    app.deriveSessionKey(gateway.getPublicKeyBase64(), appNonce, gwNonce);
    attacker.deriveSessionKey(gateway.getPublicKeyBase64(), appNonce, gwNonce);

    // Attacker creates verify with different key
    const attackerVerify = attacker.createHandshakeVerify(appNonce, gwNonce, false);
    expect(gateway.verifyHandshake(attackerVerify, appNonce, gwNonce, false)).toBe(false);
  });

  it('should throw error if session key not derived', () => {
    const manager = new CryptoManager();

    expect(() => {
      manager.encrypt('test');
    }).toThrow('Session key not derived');

    expect(() => {
      manager.decrypt({ iv: 'test', ciphertext: 'test' });
    }).toThrow('Session key not derived');
  });
});
