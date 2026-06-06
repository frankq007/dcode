import { readFileSync, existsSync } from 'fs';
import { resolve } from 'path';

export interface GatewayConfig {
  mode: 'direct' | 'relay';
  host: string;
  port: number;
  relayUrl: string;
  opencodeUrl: string;
  computerName: string;
  version: string;
}

const DEFAULT_CONFIG: GatewayConfig = {
  mode: 'direct',
  host: '0.0.0.0',
  port: 8765,
  relayUrl: 'ws://localhost:8766',
  opencodeUrl: 'http://localhost:3000',
  computerName: 'MyPC',
  version: '0.1.0'
};

export function loadConfig(configPath?: string): GatewayConfig {
  const config = { ...DEFAULT_CONFIG };

  const filePath = configPath || process.env.DCODE_CONFIG_PATH || resolve(process.cwd(), 'gateway.config.json');
  if (existsSync(filePath)) {
    try {
      const fileConfig = JSON.parse(readFileSync(filePath, 'utf8'));
      Object.assign(config, fileConfig);
    } catch (e) {
      console.warn('[Config] Failed to parse config file:', e);
    }
  }

  if (process.env.DCODE_MODE) config.mode = process.env.DCODE_MODE as 'direct' | 'relay';
  if (process.env.DCODE_HOST) config.host = process.env.DCODE_HOST;
  if (process.env.DCODE_PORT) config.port = parseInt(process.env.DCODE_PORT, 10);
  if (process.env.DCODE_RELAY_URL) config.relayUrl = process.env.DCODE_RELAY_URL;
  if (process.env.DCODE_OPENCODE_URL) config.opencodeUrl = process.env.DCODE_OPENCODE_URL;
  if (process.env.DCODE_COMPUTER_NAME) config.computerName = process.env.DCODE_COMPUTER_NAME;

  for (const arg of process.argv) {
    const [key, value] = arg.split('=');
    if (key === '--mode' && value) config.mode = value as 'direct' | 'relay';
    if (key === '--port' && value) config.port = parseInt(value, 10);
    if (key === '--relay-url' && value) config.relayUrl = value;
    if (key === '--opencode-url' && value) config.opencodeUrl = value;
  }

  return config;
}
