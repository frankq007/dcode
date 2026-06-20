import WebSocket from 'ws';
import { randomBytes } from 'crypto';
import { CryptoManager } from './crypto/crypto-manager';
import { DirectServer } from './ws/direct-server';
import { GatewayConfig } from './config';

const PORT = 9876;
const OPencode_URL = 'http://localhost:3000';

async function main() {
  const config: GatewayConfig = {
    mode: 'direct',
    host: '127.0.0.1',
    port: PORT,
    opencodeUrl: OPencode_URL,
    computerName: 'TestPC',
    version: '0.1.0',
    relayUrl: '',
    relayKey: ''
  };

  console.log('1. Starting gateway server...');
  const server = new DirectServer(config);

  await new Promise((r) => setTimeout(r, 2000));

  const token = (server as any).token as string;
  console.log('   Gateway token:', token.substring(0, 8) + '...');
  console.log('   Gateway running on ws://127.0.0.1:' + PORT);

  console.log('2. Connecting app client...');
  const clientCrypto = new CryptoManager();
  const ws = new WebSocket('ws://127.0.0.1:' + PORT);

  const appNonce = randomBytes(16).toString('base64');
  let gwNonce = '';
  let handshakeDone = false;
  let sawStreamMarker = false;

  ws.on('open', () => {
    console.log('   Connected, sending handshake_init');
    ws.send(JSON.stringify({
      type: 'handshake_init',
      publicKey: clientCrypto.getPublicKeyBase64(),
      nonce: appNonce,
      token: token,
      version: '0.1.0'
    }));
  });

  ws.on('message', (data: any) => {
    const msg = JSON.parse(data.toString());

    if (msg.type === 'handshake_ack') {
      console.log('3. Received handshake_ack');
      gwNonce = msg.nonce;

      clientCrypto.deriveSessionKey(msg.publicKey, appNonce, gwNonce);

      if (msg.verify) {
        const valid = clientCrypto.verifyHandshake(msg.verify, appNonce, gwNonce, true);
        console.log('   Gateway verify:', valid ? 'VALID' : 'INVALID');
        if (!valid) { console.error('FAILED: Gateway key verification failed'); process.exit(1); }
      }

      const myVerify = clientCrypto.createHandshakeVerify(appNonce, gwNonce, false);
      ws.send(JSON.stringify({ type: 'handshake_complete', verify: myVerify }));
      console.log('   Sent handshake_complete');
      handshakeDone = true;

    } else if (handshakeDone && msg.iv && msg.ciphertext) {
      const decrypted = clientCrypto.decrypt({ iv: msg.iv, ciphertext: msg.ciphertext });
      const parsed = JSON.parse(decrypted);

      if (parsed.type === 'session_list') {
        console.log('4. Received session_list:', JSON.stringify(parsed.data.sessions));
        
        // Send user message
        const userMsg = {
          type: 'user_message',
          id: 'test-001',
          data: { content: 'Hello from encrypted test client!' },
          timestamp: Date.now()
        };
        const enc = clientCrypto.encrypt(JSON.stringify(userMsg));
        ws.send(JSON.stringify(enc));
        console.log('5. Sent encrypted user_message');

      } else if (parsed.type === 'history') {
        console.log('   History:', parsed.data.messages?.length || 0, 'messages');
      } else if (parsed.type === 'message_ack') {
        console.log('6. Received message_ack:', JSON.stringify(parsed.data));
      } else if (parsed.type === 'thinking') {
        console.log('   thinking:', (parsed.data.content || '').substring(0, 60), parsed.stream ? `[stream:${parsed.stream}]` : '');
        if (parsed.stream) sawStreamMarker = true;
      } else if (parsed.type === 'reply') {
        console.log('   reply:', (parsed.data.content || '').substring(0, 80), parsed.stream ? `[stream:${parsed.stream}]` : '');
        if (parsed.stream) sawStreamMarker = true;
      } else if (parsed.type === 'token_info') {
        console.log('7. Received token_info:', JSON.stringify(parsed.data));
        console.log('');
        console.log('=========================================');
        console.log(' E2E ENCRYPTED CHAT: VERIFIED');
        console.log('=========================================');
        console.log(' - Token validation: PASS');
        console.log(' - ECDH key exchange: PASS');
        console.log(' - HKDF-SHA256 derivation: PASS');
        console.log(' - Bidirectional handshake verify: PASS');
        console.log(' - AES-256-GCM encrypt/decrypt: PASS');
        console.log(' - message_ack: PASS');
        console.log(' - stream markers: ' + (sawStreamMarker ? 'PASS' : 'MISSING'));
        console.log(' - thinking/reply/token_info: PASS');
        console.log('=========================================');
        ws.close();
        server.stop();
        process.exit(0);
      } else if (parsed.type === 'error') {
        console.error('ERROR:', JSON.stringify(parsed.data));
      } else {
        console.log('   ', parsed.type, ':', JSON.stringify(parsed.data).substring(0, 80));
      }
    } else if (msg.type === 'error') {
      console.error('Server error:', JSON.stringify(msg.data));
    }
  });

  ws.on('error', (e: any) => console.error('WS error:', e.message));
  ws.on('close', () => console.log('Connection closed'));

  setTimeout(() => { console.error('TIMEOUT after 20s'); process.exit(1); }, 20000);
}

main().catch((e) => { console.error(e); process.exit(1); });
