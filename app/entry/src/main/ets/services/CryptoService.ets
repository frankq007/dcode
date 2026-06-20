import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';
import { EncryptedMessage } from '../models/index';

const base64Helper = new util.Base64Helper();
const MAGIC = 'DCODE-HANDSHAKE-OK';
const INFO_LABEL = 'dcode-session-key';
const GCM_IV_LEN = 12;
const AUTH_TAG_LEN = 16;
const X25519_SPKI_HEADER: Uint8Array = new Uint8Array([0x30, 0x2a, 0x30, 0x05, 0x06, 0x03, 0x2b, 0x65, 0x6e, 0x03, 0x21, 0x00]);

export class CryptoService {
  private keyPair: cryptoFramework.KeyPair | null = null;
  private sessionKey: cryptoFramework.SymKey | null = null;
  private keyAgreement: cryptoFramework.KeyAgreement | null = null;

  async generateKeyPair(): Promise<void> {
    const generator = cryptoFramework.createAsyKeyGenerator('X25519');
    this.keyPair = await generator.generateKeyPair();
    this.keyAgreement = cryptoFramework.createKeyAgreement('X25519');
    console.log('[Crypto] X25519 key pair generated');
  }

  getPublicKeyBase64(): string {
    if (!this.keyPair) {
      throw new Error('Key pair not generated');
    }
    const pubKeyData = this.keyPair.pubKey.getEncoded();
    const derBytes = pubKeyData.data;
    const rawBytes = derBytes.subarray(derBytes.length - 32);
    return this.encodeBase64(rawBytes);
  }

  async deriveSessionKey(
    peerPublicKeyBase64: string,
    appNonceBase64: string,
    gwNonceBase64: string
  ): Promise<void> {
    if (!this.keyPair || !this.keyAgreement) {
      throw new Error('Key pair not generated');
    }

    const rawPeerPubKey = this.decodeBase64(peerPublicKeyBase64);
    const derPeerPubKey = this.concatBuffers(X25519_SPKI_HEADER, rawPeerPubKey);

    const pubKeyBlob: cryptoFramework.DataBlob = { data: derPeerPubKey };
    const emptyBlob: cryptoFramework.DataBlob = { data: new Uint8Array(0) };

    const generator = cryptoFramework.createAsyKeyGenerator('X25519');
    const peerKeyPair = await generator.convertKey(pubKeyBlob, emptyBlob);

    const sharedSecret = await this.keyAgreement.generateSecret(this.keyPair.priKey, peerKeyPair.pubKey);

    const infoData = this.concatBuffers(
      this.strToBuf(INFO_LABEL),
      this.decodeBase64(appNonceBase64),
      this.decodeBase64(gwNonceBase64)
    );

    const kdfSpec: cryptoFramework.HKDFSpec = {
      algName: 'HKDF',
      key: sharedSecret.data,
      salt: new Uint8Array(0),
      info: infoData,
      keySize: 32
    };

    const kdf = cryptoFramework.createKdf('HKDF|SHA256');
    const derivedKeyData = await kdf.generateSecret(kdfSpec);

    const symKeyGenerator = cryptoFramework.createSymKeyGenerator('AES256');
    const keyBlob: cryptoFramework.DataBlob = { data: derivedKeyData.data };
    this.sessionKey = await symKeyGenerator.convertKey(keyBlob);

    console.log('[Crypto] Session key derived via HKDF-SHA256');
  }

  async createHandshakeVerify(
    appNonceBase64: string,
    gwNonceBase64: string,
    isApp: boolean
  ): Promise<EncryptedMessage> {
    if (!this.sessionKey) {
      throw new Error('Session key not derived');
    }

    const appNonce = this.decodeBase64(appNonceBase64);
    const gwNonce = this.decodeBase64(gwNonceBase64);

    const plaintext = isApp
      ? this.concatBuffers(this.strToBuf(MAGIC), appNonce, gwNonce)
      : this.concatBuffers(this.strToBuf(MAGIC), gwNonce, appNonce);

    const iv = new Uint8Array(GCM_IV_LEN);
    return await this.encryptRaw(plaintext, iv);
  }

  async verifyHandshake(
    verify: EncryptedMessage,
    appNonceBase64: string,
    gwNonceBase64: string,
    isGateway: boolean
  ): Promise<boolean> {
    if (!this.sessionKey) {
      throw new Error('Session key not derived');
    }

    try {
      const iv = this.decodeBase64(verify.iv);
      const data = this.decodeBase64(verify.ciphertext);
      const decrypted = await this.decryptRaw(data, iv);

      const appNonce = this.decodeBase64(appNonceBase64);
      const gwNonce = this.decodeBase64(gwNonceBase64);
      const expected = isGateway
        ? this.concatBuffers(this.strToBuf(MAGIC), gwNonce, appNonce)
        : this.concatBuffers(this.strToBuf(MAGIC), appNonce, gwNonce);

      return this.buffersEqual(decrypted, expected);
    } catch (e) {
      console.error('[Crypto] Verify failed:', e);
      return false;
    }
  }

  async encrypt(plaintext: string): Promise<EncryptedMessage> {
    if (!this.sessionKey) {
      throw new Error('Session key not derived');
    }

    const plainBytes = this.strToBuf(plaintext);
    const rand = cryptoFramework.createRandom();
    const ivData = rand.generateRandomSync(GCM_IV_LEN);

    const ivBlob: cryptoFramework.DataBlob = { data: ivData.data };
    const aadBlob: cryptoFramework.DataBlob = { data: new Uint8Array(0) };
    const tagBlob: cryptoFramework.DataBlob = { data: new Uint8Array(AUTH_TAG_LEN) };

    const gcmParams: cryptoFramework.GcmParamsSpec = {
      algName: 'GcmParamsSpec',
      iv: ivBlob,
      aad: aadBlob,
      authTag: tagBlob
    };

    const cipher = cryptoFramework.createCipher('AES256|GCM');
    await cipher.init(cryptoFramework.CryptoMode.ENCRYPT_MODE, this.sessionKey, gcmParams);

    const plainBlob: cryptoFramework.DataBlob = { data: plainBytes };
    const encrypted = await cipher.doFinal(plainBlob);

    const encData = encrypted.data;
    const authTag = encData.subarray(encData.length - AUTH_TAG_LEN);
    const ciphertext = encData.subarray(0, encData.length - AUTH_TAG_LEN);
    const combined = this.concatBuffers(ciphertext, authTag);

    const result: EncryptedMessage = {
      iv: this.encodeBase64(ivData.data),
      ciphertext: this.encodeBase64(combined)
    };
    return result;
  }

  async decrypt(encrypted: EncryptedMessage): Promise<string> {
    if (!this.sessionKey) {
      throw new Error('Session key not derived');
    }

    const iv = this.decodeBase64(encrypted.iv);
    const data = this.decodeBase64(encrypted.ciphertext);

    const ciphertext = data.subarray(0, data.length - AUTH_TAG_LEN);
    const authTag = data.subarray(data.length - AUTH_TAG_LEN);

    const ivBlob: cryptoFramework.DataBlob = { data: iv };
    const aadBlob: cryptoFramework.DataBlob = { data: new Uint8Array(0) };
    const tagBlob: cryptoFramework.DataBlob = { data: authTag };

    const gcmParams: cryptoFramework.GcmParamsSpec = {
      algName: 'GcmParamsSpec',
      iv: ivBlob,
      aad: aadBlob,
      authTag: tagBlob
    };

    const cipher = cryptoFramework.createCipher('AES256|GCM');
    await cipher.init(cryptoFramework.CryptoMode.DECRYPT_MODE, this.sessionKey, gcmParams);

    const cipherBlob: cryptoFramework.DataBlob = { data: ciphertext };
    const decrypted = await cipher.doFinal(cipherBlob);
    return this.bufToStr(decrypted.data);
  }

  private async encryptRaw(plaintext: Uint8Array, iv: Uint8Array): Promise<EncryptedMessage> {
    if (!this.sessionKey) {
      throw new Error('Session key not derived');
    }

    const ivBlob: cryptoFramework.DataBlob = { data: iv };
    const aadBlob: cryptoFramework.DataBlob = { data: new Uint8Array(0) };
    const tagBlob: cryptoFramework.DataBlob = { data: new Uint8Array(AUTH_TAG_LEN) };

    const gcmParams: cryptoFramework.GcmParamsSpec = {
      algName: 'GcmParamsSpec',
      iv: ivBlob,
      aad: aadBlob,
      authTag: tagBlob
    };

    const cipher = cryptoFramework.createCipher('AES256|GCM');
    await cipher.init(cryptoFramework.CryptoMode.ENCRYPT_MODE, this.sessionKey, gcmParams);

    const plainBlob: cryptoFramework.DataBlob = { data: plaintext };
    const encrypted = await cipher.doFinal(plainBlob);

    const encData = encrypted.data;
    const authTag = encData.subarray(encData.length - AUTH_TAG_LEN);
    const ciphertext = encData.subarray(0, encData.length - AUTH_TAG_LEN);
    const combined = this.concatBuffers(ciphertext, authTag);

    const result: EncryptedMessage = {
      iv: this.encodeBase64(iv),
      ciphertext: this.encodeBase64(combined)
    };
    return result;
  }

  private async decryptRaw(data: Uint8Array, iv: Uint8Array): Promise<Uint8Array> {
    if (!this.sessionKey) {
      throw new Error('Session key not derived');
    }

    const ciphertext = data.subarray(0, data.length - AUTH_TAG_LEN);
    const authTag = data.subarray(data.length - AUTH_TAG_LEN);

    const ivBlob: cryptoFramework.DataBlob = { data: iv };
    const aadBlob: cryptoFramework.DataBlob = { data: new Uint8Array(0) };
    const tagBlob: cryptoFramework.DataBlob = { data: authTag };

    const gcmParams: cryptoFramework.GcmParamsSpec = {
      algName: 'GcmParamsSpec',
      iv: ivBlob,
      aad: aadBlob,
      authTag: tagBlob
    };

    const cipher = cryptoFramework.createCipher('AES256|GCM');
    await cipher.init(cryptoFramework.CryptoMode.DECRYPT_MODE, this.sessionKey, gcmParams);

    const cipherBlob: cryptoFramework.DataBlob = { data: ciphertext };
    const decrypted = await cipher.doFinal(cipherBlob);
    return decrypted.data;
  }

  generateNonce(): string {
    const rand = cryptoFramework.createRandom();
    const nonceData = rand.generateRandomSync(16);
    return this.encodeBase64(nonceData.data);
  }

  private decodeBase64(b64: string): Uint8Array {
    return base64Helper.decodeSync(b64);
  }

  private encodeBase64(data: Uint8Array): string {
    return base64Helper.encodeToStringSync(data);
  }

  private strToBuf(s: string): Uint8Array {
    const encoder = new util.TextEncoder();
    return encoder.encodeInto(s);
  }

  private bufToStr(data: Uint8Array): string {
    const decoder = new util.TextDecoder();
    return decoder.decodeToString(data);
  }

  private concatBuffers(...buffers: Uint8Array[]): Uint8Array {
    let totalLen = 0;
    for (const b of buffers) {
      totalLen += b.length;
    }
    const result = new Uint8Array(totalLen);
    let offset = 0;
    for (const b of buffers) {
      result.set(b, offset);
      offset += b.length;
    }
    return result;
  }

  private buffersEqual(a: Uint8Array, b: Uint8Array): boolean {
    if (a.length !== b.length) return false;
    for (let i = 0; i < a.length; i++) {
      if (a[i] !== b[i]) return false;
    }
    return true;
  }
}


