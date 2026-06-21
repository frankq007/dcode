import WebSocket from 'ws';
import { randomBytes } from 'crypto';
import { CryptoManager } from './crypto/crypto-manager';

const GW_URL = 'ws://127.0.0.1:8765';
const TOKEN = 'dcode-dev-token-0001';

async function main() {
  const crypto = new CryptoManager();
  const appNonce = randomBytes(16).toString('base64');
  let gwNonce = '';
  let handshakeDone = false;
  let sawStream = false;
  const replyStreams: string[] = [];
  const checks: Record<string, boolean> = {};

  console.log('=== E2E: App -> Gateway(8765) -> Real opencode(3000) ===');
  const ws = new WebSocket(GW_URL);

  ws.on('open', () => {
    console.log('[1] Connected to gateway');
    ws.send(JSON.stringify({
      type: 'handshake_init',
      publicKey: crypto.getPublicKeyBase64(),
      nonce: appNonce,
      token: TOKEN,
      version: '0.1.0'
    }));
    console.log('[2] Sent handshake_init');
  });

  ws.on('message', (data: any) => {
    const raw = data.toString();
    let msg: any;
    try { msg = JSON.parse(raw); } catch { return; }

    if (msg.type === 'handshake_ack') {
      gwNonce = msg.nonce;
      crypto.deriveSessionKey(msg.publicKey, appNonce, gwNonce);
      checks['ECDH+HKDF'] = true;
      checks['Token'] = true;

      if (msg.verify) {
        const valid = crypto.verifyHandshake(msg.verify, appNonce, gwNonce, true);
        checks['GwVerify'] = valid;
        console.log('[3] Gateway verify: ' + (valid ? 'VALID' : 'INVALID'));
        if (!valid) { ws.close(); process.exit(1); }
      }

      const myVerify = crypto.createHandshakeVerify(appNonce, gwNonce, false);
      ws.send(JSON.stringify({ type: 'handshake_complete', verify: myVerify }));
      console.log('[4] Sent handshake_complete');
      handshakeDone = true;

    } else if (handshakeDone && msg.iv && msg.ciphertext) {
      let parsed: any;
      try {
        const dec = crypto.decrypt({ iv: msg.iv, ciphertext: msg.ciphertext });
        parsed = JSON.parse(dec);
      } catch {
        console.log('     (skip large msg, len=' + raw.length + ')');
        return;
      }
      checks['AES'] = true;

      if (parsed.type === 'session_list') {
        checks['sessions'] = true;
        console.log('[5] session_list: ' + parsed.data.sessions.length + ' sessions');

        const userMsg = {
          type: 'user_message', id: 'e2e-003',
          data: { content: 'Say hi briefly' }, timestamp: Date.now()
        };
        ws.send(JSON.stringify(crypto.encrypt(JSON.stringify(userMsg))));
        console.log('[6] Sent encrypted user_message');

      } else if (parsed.type === 'history') {
        checks['history'] = true;
        console.log('     history: ' + (parsed.data.messages?.length || 0) + ' msgs');

      } else if (parsed.type === 'message_ack') {
        checks['ack'] = true;
        console.log('[7] message_ack OK');

      } else if (parsed.type === 'thinking') {
        checks['thinking'] = true;
        if (parsed.stream) sawStream = true;
        console.log('     thinking [' + parsed.stream + ']: ' + (parsed.data.content || '').substring(0, 60));

      } else if (parsed.type === 'reply') {
        checks['reply'] = true;
        if (parsed.stream) sawStream = true;
        replyStreams.push(parsed.stream || 'none');
        console.log('     reply [' + parsed.stream + ']: ' + (parsed.data.content || '').substring(0, 100));

      } else if (parsed.type === 'token_info') {
        checks['tokens'] = true;
        console.log('[8] token_info: ' + JSON.stringify(parsed.data));

      } else if (parsed.type === 'thinking' && parsed.stream === 'end') {
        // thinking end signals completion in SSE mode
      }
      if (parsed.type === 'reply' && parsed.stream === 'end') {
        console.log('[9] reply stream=end - SSE flow complete');
      }
      if (parsed.type === 'thinking' && parsed.stream === 'end' && checks['reply']) {
        // Final: thinking end after reply end = complete
        const replyStart = replyStreams.includes('start');
        const replyEnd = replyStreams.includes('end');
        const all = ['Token','ECDH+HKDF','GwVerify','AES','sessions','history','ack','thinking','reply','tokens'];
        console.log('');
        console.log('=========================================');
        let pass = 0;
        for (const k of all) {
          const ok = checks[k];
          if (ok) pass++;
          console.log('  ' + (ok ? 'PASS' : 'FAIL') + ' - ' + k);
        }
        if (sawStream) { pass++; console.log('  PASS - stream markers'); }
        else console.log('  FAIL - stream markers');
        if (replyStart) { pass++; console.log('  PASS - reply stream=start (SSE incremental)'); }
        else console.log('  FAIL - reply stream=start (SSE incremental)');
        if (replyStreams.includes('append') || replyStreams.includes('replace')) {
          pass++; console.log('  PASS - reply stream=append/replace (delta)'); }
        else console.log('  FAIL - reply stream=append/replace (delta)');
        if (replyEnd) { pass++; console.log('  PASS - reply stream=end'); }
        else console.log('  FAIL - reply stream=end');

        const total = all.length + 4;
        console.log('=========================================');
        console.log('  ' + pass + '/' + total + ' checks passed');
        console.log('  reply streams seen: ' + JSON.stringify(replyStreams));
        if (pass === total) console.log('  ALL PASSED');
        console.log('=========================================');

        ws.close();
        process.exit(pass === total ? 0 : 1);
      } else if (parsed.type === 'error') {
        console.error('ERROR: ' + JSON.stringify(parsed.data));
      }
    } else if (msg.type === 'error') {
      console.error('Server error: ' + JSON.stringify(msg.data));
      if (msg.data?.code === 'INVALID_TOKEN') checks['Token'] = false;
    }
  });

  ws.on('error', (e: any) => console.error('WS error: ' + e.message));
  ws.on('close', () => { console.log('Closed'); });

  setTimeout(() => { console.error('TIMEOUT 120s'); process.exit(1); }, 120000);
}

main().catch((e) => { console.error(e); process.exit(1); });
