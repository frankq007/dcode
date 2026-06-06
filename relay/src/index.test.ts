import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { WebSocket } from 'ws';
import { RelayServer } from './index';

describe('Relay Server', () => {
  let server: any;
  const TEST_PORT = 18765;

  beforeEach(() => {
    // Dynamic import to avoid module loading issues
    server = null;
  });

  afterEach(() => {
    if (server) {
      server.stop();
    }
  });

  it('should accept connections and pair gateway with app', (done) => {
    const { RelayServer: RS } = require('./index');
    server = new RS(TEST_PORT);

    const token = 'test-token-123';

    // Connect gateway first
    const gatewayWs = new WebSocket(`ws://localhost:${TEST_PORT}`);
    
    gatewayWs.on('open', () => {
      gatewayWs.send(JSON.stringify({
        type: 'register',
        token,
        role: 'gateway'
      }));
    });

    gatewayWs.on('message', (data: any) => {
      const msg = JSON.parse(data.toString());
      
      if (msg.type === 'waiting') {
        // Now connect app
        const appWs = new WebSocket(`ws://localhost:${TEST_PORT}`);
        
        appWs.on('open', () => {
          appWs.send(JSON.stringify({
            type: 'register',
            token,
            role: 'app'
          }));
        });

        appWs.on('message', (data: any) => {
          const appMsg = JSON.parse(data.toString());
          if (appMsg.type === 'paired') {
            expect(appMsg.token).toBe(token);
            gatewayWs.close();
            appWs.close();
            done();
          }
        });
      }
    });
  }, 10000);

  it('should forward messages between paired clients', (done) => {
    const { RelayServer: RS } = require('./index');
    server = new RS(TEST_PORT);

    const token = 'forward-test-token';
    const testPayload = { type: 'test_message', data: { hello: 'world' } };

    // Connect and pair
    const gatewayWs = new WebSocket(`ws://localhost:${TEST_PORT}`);
    let appWs: WebSocket;

    gatewayWs.on('open', () => {
      gatewayWs.send(JSON.stringify({ type: 'register', token, role: 'gateway' }));
    });

    gatewayWs.on('message', (data: any) => {
      const msg = JSON.parse(data.toString());
      
      if (msg.type === 'waiting') {
        appWs = new WebSocket(`ws://localhost:${TEST_PORT}`);
        
        appWs.on('open', () => {
          appWs.send(JSON.stringify({ type: 'register', token, role: 'app' }));
        });

        appWs.on('message', (data: any) => {
          const appMsg = JSON.parse(data.toString());
          
          if (appMsg.type === 'paired') {
            // Send test message from gateway to app
            gatewayWs.send(JSON.stringify(testPayload));
          } else if (appMsg.type === 'test_message') {
            expect(appMsg.data.hello).toBe('world');
            gatewayWs.close();
            appWs.close();
            done();
          }
        });
      }
    });
  }, 10000);
});
