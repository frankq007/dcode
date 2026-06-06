import { describe, it, expect } from 'vitest';
import { CryptoManager } from './crypto-manager';

describe('CryptoManager', () => {
  it('should generate X25519 key pair', () => {
    const manager = new CryptoManager();
    const publicKey = manager.getPublicKeyBase64();
    
    expect(publicKey).toBeDefined();
    expect(typeof publicKey).toBe('string');
    expect(publicKey.length).toBeGreaterThan(0);
  });

  it('should derive session key from peer public key', () => {
    const manager1 = new CryptoManager();
    const manager2 = new CryptoManager();
    
    const nonce1 = 'test-nonce-1';
    const nonce2 = 'test-nonce-2';
    
    manager1.deriveSessionKey(manager2.getPublicKeyBase64(), nonce1, nonce2);
    manager2.deriveSessionKey(manager1.getPublicKeyBase64(), nonce1, nonce2);
    
    const plaintext = 'Hello, encrypted world!';
    const encrypted = manager1.encrypt(plaintext);
    const decrypted = manager2.decrypt(encrypted);
    
    expect(decrypted).toBe(plaintext);
  });

  it('should encrypt and decrypt messages correctly', () => {
    const manager1 = new CryptoManager();
    const manager2 = new CryptoManager();
    
    const nonce1 = 'nonce1';
    const nonce2 = 'nonce2';
    
    manager1.deriveSessionKey(manager2.getPublicKeyBase64(), nonce1, nonce2);
    manager2.deriveSessionKey(manager1.getPublicKeyBase64(), nonce1, nonce2);
    
    const testMessages = [
      'Short message',
      'A longer message with special characters: !@#$%^&*()',
      JSON.stringify({ type: 'test', data: { nested: 'object' } }),
      '中文测试消息'
    ];
    
    for (const msg of testMessages) {
      const encrypted = manager1.encrypt(msg);
      const decrypted = manager2.decrypt(encrypted);
      expect(decrypted).toBe(msg);
    }
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
