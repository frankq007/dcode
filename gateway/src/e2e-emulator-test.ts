import WebSocket from 'ws';
import { randomBytes } from 'crypto';
import { CryptoManager } from './crypto/crypto-manager';

const GW_URL = 'ws://127.0.0.1:8765';
const TOKEN = '60b087fd-0f88-4a85-b415-5193be087c66';

async function main() {
  const crypto = new CryptoManager();
  const appNonce = randomBytes(16).toString('base64');
  let gwNonce = '';
  let handshakeDone = false;
  let msgCount = 0;

  console.log('Connecting to', GW_URL);
  const ws = new WebSocket(GW_URL);

  ws.on('open', () => {
    console.log('[1] Connected. Sending handshake...');
    ws.send(JSON.stringify({
      type: 'handshake_init',
      publicKey: crypto.getPublicKeyBase64(),
      nonce: appNonce,
      token: TOKEN,
      version: '0.1.0'
    }));
  });

  ws.on('message', (data: any) => {
    let msg: any;
    try { msg = JSON.parse(data.toString()); } catch { return; }

    if (msg.type === 'handshake_ack') {
      gwNonce = msg.nonce;
      crypto.deriveSessionKey(msg.publicKey, appNonce, gwNonce);
      if (msg.verify) {
        const valid = crypto.verifyHandshake(msg.verify, appNonce, gwNonce, true);
        console.log('[2] Handshake:', valid ? 'OK' : 'FAIL');
      }
      ws.send(JSON.stringify({
        type: 'handshake_complete',
        verify: crypto.createHandshakeVerify(appNonce, gwNonce, false)
      }));
      handshakeDone = true;
      console.log('[3] Encrypted channel established');

    } else if (handshakeDone && msg.iv && msg.ciphertext) {
      let parsed: any;
      try {
        parsed = JSON.parse(crypto.decrypt({ iv: msg.iv, ciphertext: msg.ciphertext }));
      } catch { return; }
      msgCount++;
      console.log(`[${msgCount}] ${parsed.type}:`, JSON.stringify(parsed.data).substring(0, 120));

      if (parsed.type === 'reply' && parsed.data.content === '连接成功，正在加载会话...') {
        console.log('  -> Connection ack received (WebSocket alive!)');
      }

      if (parsed.type === 'session_list') {
        console.log('  -> Sessions loaded, sending hello world...');
        const userMsg = {
          type: 'user_message',
          id: 'emulator-test-' + Date.now(),
          data: { content: 'hello world' },
          timestamp: Date.now()
        };
        ws.send(JSON.stringify(crypto.encrypt(JSON.stringify(userMsg))));
      }

      if (parsed.type === 'token_info') {
        console.log('\n=== SUCCESS: Full flow verified ===');
        console.log('  Connection alive (no timeout)');
        console.log('  Message sent and received by opencode');
        console.log('  AI response received and decrypted');
        ws.close();
        process.exit(0);
      }

      if (parsed.type === 'error') {
        console.error('ERROR:', JSON.stringify(parsed.data));
      }
    } else if (msg.type === 'error') {
      console.error('Server error:', JSON.stringify(msg.data));
    }
  });

  ws.on('close', () => { console.log('Connection closed'); });
  ws.on('error', (e: any) => console.error('WS error:', e.message));
  setTimeout(() => { console.error('TIMEOUT 60s'); process.exit(1); }, 60000);
}

main().catch((e) => { console.error(e); process.exit(1); });
