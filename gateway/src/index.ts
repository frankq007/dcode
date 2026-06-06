import { loadConfig } from './config';
import { DirectServer } from './ws/direct-server';

const config = loadConfig();

console.log('[Gateway] Starting with config:');
console.log(`  Mode: ${config.mode}`);
console.log(`  Host: ${config.host}:${config.port}`);
console.log(`  OpenCode URL: ${config.opencodeUrl}`);
console.log(`  Computer Name: ${config.computerName}`);
console.log(`  Version: ${config.version}`);

if (config.mode === 'relay') {
  console.log(`  Relay URL: ${config.relayUrl}`);
  console.log('[Gateway] Relay mode not yet implemented, falling back to direct mode');
}

const server = new DirectServer(config);

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
