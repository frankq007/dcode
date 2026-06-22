import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { WebSocket } from 'ws';
import { RelayServer as RS } from './index';

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

  it('should send paired to both app and gateway when gateway already registered', (done) => {
    server = new RS(TEST_PORT);

    const token = 'gw-registered-token';
    const gatewayWs = new WebSocket(`ws://localhost:${TEST_PORT}`);
    let gwPaired = false;
    let appPaired = false;
    let appWs: WebSocket | null = null;

    const maybeDone = (): void => {
      if (gwPaired && appPaired && appWs) {
        gatewayWs.close();
        appWs.close();
        done();
      }
    };

    gatewayWs.on('open', () => {
      gatewayWs.send(JSON.stringify({ type: 'register', token, role: 'gateway' }));
    });

    gatewayWs.on('message', (data: any) => {
      const msg = JSON.parse(data.toString());
      if (msg.type === 'waiting') {
        appWs = new WebSocket(`ws://localhost:${TEST_PORT}`);
        appWs.on('open', () => {
          appWs!.send(JSON.stringify({ type: 'register', token, role: 'app' }));
        });
        appWs.on('message', (d: any) => {
          const m = JSON.parse(d.toString());
          if (m.type === 'paired') {
            expect(m.token).toBe(token);
            appPaired = true;
            maybeDone();
          }
        });
      } else if (msg.type === 'paired') {
        gwPaired = true;
        maybeDone();
      }
    });
  }, 10000);

  it('should send waiting to app when gateway not registered', (done) => {
    server = new RS(TEST_PORT);

    const token = 'no-gateway-token';
    const appWs = new WebSocket(`ws://localhost:${TEST_PORT}`);

    appWs.on('open', () => {
      appWs.send(JSON.stringify({ type: 'register', token, role: 'app' }));
    });

    appWs.on('message', (data: any) => {
      const msg = JSON.parse(data.toString());
      if (msg.type === 'waiting') {
        expect(msg.token).toBe(token);
        appWs.close();
        done();
      }
    });
  }, 10000);

  it('should let app rejoin an existing paired session (app-after)', (done) => {
    server = new RS(TEST_PORT);

    const token = 'app-after-token';
    const gatewayWs = new WebSocket(`ws://localhost:${TEST_PORT}`);
    const clients: WebSocket[] = [];

    gatewayWs.on('open', () => {
      gatewayWs.send(JSON.stringify({ type: 'register', token, role: 'gateway' }));
    });

    gatewayWs.on('message', (data: any) => {
      const msg = JSON.parse(data.toString());
      if (msg.type === 'waiting') {
        // gateway is waiting -> connect app1 to form an active session
        const app1Ws = new WebSocket(`ws://localhost:${TEST_PORT}`);
        clients.push(app1Ws);
        app1Ws.on('open', () => {
          app1Ws.send(JSON.stringify({ type: 'register', token, role: 'app' }));
        });
        app1Ws.on('message', (d: any) => {
          const m = JSON.parse(d.toString());
          if (m.type === 'paired') {
            // app1 paired -> app2 registers while gateway is in activeSessions
            const app2Ws = new WebSocket(`ws://localhost:${TEST_PORT}`);
            clients.push(app2Ws);
            app2Ws.on('open', () => {
              app2Ws.send(JSON.stringify({ type: 'register', token, role: 'app' }));
            });
            app2Ws.on('message', (d2: any) => {
              const m2 = JSON.parse(d2.toString());
              if (m2.type === 'paired') {
                // app2 rejoined the active session -> forward a message to gateway
                app2Ws.send(JSON.stringify({ type: 'relay_test', payload: 'from-app2' }));
              }
            });
          }
        });
      } else if (msg.type === 'relay_test') {
        // forwarded from app2 -> app2 is now the gateway's peer
        expect(msg.payload).toBe('from-app2');
        gatewayWs.close();
        clients.forEach(c => c.close());
        done();
      }
    });
  }, 15000);

  it('should kick old app with reason:replaced when duplicate app registers (R2.1)', (done) => {
    server = new RS(TEST_PORT);

    const token = 'replaced-token';
    const gatewayWs = new WebSocket(`ws://localhost:${TEST_PORT}`);
    const clients: WebSocket[] = [];

    gatewayWs.on('open', () => {
      gatewayWs.send(JSON.stringify({ type: 'register', token, role: 'gateway' }));
    });

    gatewayWs.on('message', (data: any) => {
      const msg = JSON.parse(data.toString());
      if (msg.type === 'waiting') {
        // Connect app1
        const app1Ws = new WebSocket(`ws://localhost:${TEST_PORT}`);
        clients.push(app1Ws);

        app1Ws.on('open', () => {
          app1Ws.send(JSON.stringify({ type: 'register', token, role: 'app' }));
        });

        app1Ws.on('message', (d: any) => {
          const m = JSON.parse(d.toString());
          if (m.type === 'paired') {
            // app1 paired, now connect app2 to replace it
            const app2Ws = new WebSocket(`ws://localhost:${TEST_PORT}`);
            clients.push(app2Ws);

            app2Ws.on('open', () => {
              app2Ws.send(JSON.stringify({ type: 'register', token, role: 'app' }));
            });
          } else if (m.type === 'peer_disconnected' && m.reason === 'replaced') {
            // app1 received replaced notification
            expect(m.reason).toBe('replaced');
            gatewayWs.close();
            clients.forEach(c => c.close());
            done();
          }
        });
      }
    });
  }, 15000);

  it('should reject registration with wrong relayKey (R2.3)', (done) => {
    server = new RS(TEST_PORT, 'correct-key-123');

    const token = 'relaykey-test';
    const ws = new WebSocket(`ws://localhost:${TEST_PORT}`);
    let finished = false;

    const finish = (): void => {
      if (finished) return;
      finished = true;
      ws.close();
      done();
    };

    ws.on('open', () => {
      ws.send(JSON.stringify({ type: 'register', token, role: 'app', relayKey: 'wrong-key' }));
    });

    ws.on('message', (data: any) => {
      const msg = JSON.parse(data.toString());
      if (msg.type === 'error') {
        expect(msg.message).toContain('Unauthorized');
        finish();
      }
    });

    ws.on('close', () => {
      // Connection should be closed by relay after sending error
      finish();
    });
  }, 10000);

  it('should accept registration with correct relayKey (R2.3)', (done) => {
    server = new RS(TEST_PORT, 'my-secret-key');

    const token = 'relaykey-ok-test';
    const ws = new WebSocket(`ws://localhost:${TEST_PORT}`);

    ws.on('open', () => {
      ws.send(JSON.stringify({ type: 'register', token, role: 'app', relayKey: 'my-secret-key' }));
    });

    ws.on('message', (data: any) => {
      const msg = JSON.parse(data.toString());
      if (msg.type === 'waiting') {
        expect(msg.token).toBe(token);
        ws.close();
        done();
      }
    });
  }, 10000);

  it('should clean up pending clients after 60s (R2.5)', async () => {
    // Let connections from previous tests fully close
    await new Promise(resolve => setTimeout(resolve, 200));

    vi.useFakeTimers({ toFake: ['setTimeout', 'setInterval', 'Date'] });
    vi.clearAllTimers();
    server = new RS(TEST_PORT);

    const token = 'pending-timeout-token';
    const gatewayWs = new WebSocket(`ws://localhost:${TEST_PORT}`);

    let gotWaiting = false;
    gatewayWs.on('message', (data: any) => {
      const msg = JSON.parse(data.toString());
      if (msg.type === 'waiting') gotWaiting = true;
    });
    gatewayWs.on('open', () => {
      gatewayWs.send(JSON.stringify({ type: 'register', token, role: 'gateway' }));
    });

    // Advance fake timers while yielding to real I/O so the connection can open
    for (let i = 0; i < 50 && !gotWaiting; i++) {
      await vi.advanceTimersByTimeAsync(100);
      await new Promise(resolve => setImmediate(resolve));
    }
    expect(gotWaiting).toBe(true);

    const closed = new Promise<void>((resolve) => {
      gatewayWs.on('close', () => resolve());
    });

    // Advance past 60s pending timeout; heartbeat checks at 30s/60s/90s
    for (let i = 0; i < 50 && gatewayWs.readyState !== WebSocket.CLOSED; i++) {
      await vi.advanceTimersByTimeAsync(2000);
      await new Promise(resolve => setImmediate(resolve));
    }
    await closed;

    expect(gatewayWs.readyState).toBe(WebSocket.CLOSED);

    vi.useRealTimers();
    vi.clearAllTimers();
    gatewayWs.close();
  }, 15000);
});
