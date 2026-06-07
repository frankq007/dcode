import { loadConfig } from './config';
import { DirectServer } from './ws/direct-server';
import { RelayClient } from './ws/relay-client';

const config = loadConfig();

console.log('[Gateway] Starting with config:');
console.log(`  Mode: ${config.mode}`);
console.log(`  Host: ${config.host}:${config.port}`);
console.log(`  OpenCode URL: ${config.opencodeUrl}`);
console.log(`  Computer Name: ${config.computerName}`);
console.log(`  Version: ${config.version}`);

let server: DirectServer | RelayClient;

if (config.mode === 'relay') {
  console.log(`  Relay URL: ${config.relayUrl}`);
  server = new RelayClient(config);
  server.start();
} else {
  server = new DirectServer(config);
}

process.on('SIGINT', () => {
  console.log('\n[Gateway] Shutting down...');
  server.stop();
  process.exit(0);
});

process.on('SIGTERM', () => {
  console.log('\n[Gateway] Shutting down...');
  server.stop();
  process.exit(0);
});
