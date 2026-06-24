import { WebSocketServer, WebSocket, RawData } from 'ws';

interface RegisteredClient {
  ws: WebSocket;
  role: 'gateway' | 'app';
  token: string;
  registeredAt: number;
  lastHeartbeat: number;
}

interface PairedSession {
  gateway: RegisteredClient;
  app: RegisteredClient;
}

export interface RelayServerOptions {
  relayKey?: string;
  pendingTimeout?: number;
  heartbeatInterval?: number;
}

export class RelayServer {
  private wss: WebSocketServer;
  private pendingClients: Map<string, RegisteredClient[]> = new Map();
  private activeSessions: Map<string, PairedSession> = new Map();
  private heartbeatInterval: NodeJS.Timeout | null = null;
  private messageCounts: Map<WebSocket, { count: number; resetAt: number }> = new Map();
  private readonly RATE_LIMIT = 100;
  private readonly RATE_LIMIT_WINDOW = 60000;
  private readonly HEARTBEAT_INTERVAL: number;
  private readonly HEARTBEAT_TIMEOUT = 90000;
  private readonly PENDING_TIMEOUT: number;
  private relayKey: string | undefined;

  constructor(private port: number = 8766, options?: string | RelayServerOptions) {
    const opts: RelayServerOptions = typeof options === 'string'
      ? { relayKey: options }
      : (options || {});

    this.relayKey = opts.relayKey || process.env.DCODE_RELAY_KEY || undefined;
    this.PENDING_TIMEOUT = opts.pendingTimeout ?? 60000;
    this.HEARTBEAT_INTERVAL = opts.heartbeatInterval ?? 30000;
    this.wss = new WebSocketServer({ port: this.port });
    this.setupServer();
    this.startHeartbeatCheck();
  }

  private setupServer(): void {
    this.wss.on('listening', () => {
      console.log(`[Relay] Server listening on port ${this.port}`);
    });

    this.wss.on('connection', (ws: WebSocket, req) => {
      console.log('[Relay] New connection from:', req.socket.remoteAddress);

      ws.on('message', (data: RawData) => {
        this.handleMessage(ws, data);
      });

      ws.on('close', () => {
        this.handleDisconnect(ws);
      });

      ws.on('error', (error) => {
        console.error('[Relay] WebSocket error:', error.message);
      });
    });
  }

  private handleMessage(ws: WebSocket, data: RawData): void {
    if (!this.checkRateLimit(ws)) {
      this.sendError(ws, 'Rate limit exceeded');
      ws.close();
      return;
    }

    const message = data.toString();
    let parsed: any;

    try {
      parsed = JSON.parse(message);
    } catch (e) {
      this.forwardMessage(ws, data);
      return;
    }

    if (parsed.type === 'register') {
      this.handleRegistration(ws, parsed);
    } else {
      this.forwardMessage(ws, data);
    }
  }

  private handleRegistration(ws: WebSocket, message: any): void {
    const { token, role, relayKey } = message;

    if (!token || !role || !['gateway', 'app'].includes(role)) {
      this.sendError(ws, 'Invalid registration: missing token or role');
      return;
    }

    if (this.relayKey && relayKey !== this.relayKey) {
      console.warn('[Relay] Unauthorized registration: relayKey mismatch');
      this.sendError(ws, 'Unauthorized');
      ws.close();
      return;
    }

    console.log(`[Relay] Registration: token=${token.substring(0, 8)}..., role=${role}`);

    const client: RegisteredClient = {
      ws,
      role,
      token,
      registeredAt: Date.now(),
      lastHeartbeat: Date.now()
    };

    const pending = this.pendingClients.get(token) || [];
    const existing = pending.find(c => c.role !== role);

    if (existing) {
      const session: PairedSession = {
        gateway: role === 'gateway' ? client : existing,
        app: role === 'app' ? client : existing
      };

      this.activeSessions.set(token, session);

      const newPending = pending.filter(c => c !== existing);
      if (newPending.length > 0) {
        this.pendingClients.set(token, newPending);
      } else {
        this.pendingClients.delete(token);
      }

      this.notifyPaired(session);
      console.log(`[Relay] Session paired: token=${token.substring(0, 8)}...`);
      return;
    }

    // No pending peer. When an app registers, a gateway may already be paired
    // in an active session with a (now stale) app — e.g. the previous app's
    // socket died silently. Let this app take over the app side of that session
    // so it pairs immediately instead of waiting forever.
    if (role === 'app') {
      const activeSession = this.activeSessions.get(token);
      if (activeSession) {
        const oldApp = activeSession.app;
        if (oldApp && oldApp.ws.readyState === WebSocket.OPEN) {
          oldApp.ws.send(JSON.stringify({ type: 'peer_disconnected', reason: 'replaced' }));
          console.log(`[Relay] Old app replaced: token=${token.substring(0, 8)}...`);
          oldApp.ws.close();
        }
        activeSession.app = client;
        this.notifyPaired(activeSession);
        console.log(`[Relay] App rejoined active session: token=${token.substring(0, 8)}...`);
        return;
      }
    }

    pending.push(client);
    this.pendingClients.set(token, pending);

    const waitingMessage = JSON.stringify({ type: 'waiting', token });
    ws.send(waitingMessage);
  }

  private notifyPaired(session: PairedSession): void {
    const token = session.gateway.token;
    const pairedMessage = JSON.stringify({ type: 'paired', token });
    if (session.gateway.ws.readyState === WebSocket.OPEN) {
      session.gateway.ws.send(pairedMessage);
    }
    if (session.app.ws.readyState === WebSocket.OPEN) {
      session.app.ws.send(pairedMessage);
    }
  }

  private forwardMessage(ws: WebSocket, data: RawData): void {
    for (const [token, session] of this.activeSessions.entries()) {
      let peer: WebSocket | null = null;

      if (session.gateway.ws === ws) {
        peer = session.app.ws;
      } else if (session.app.ws === ws) {
        peer = session.gateway.ws;
      }

      if (peer && peer.readyState === WebSocket.OPEN) {
        peer.send(data);

        const client = session.gateway.ws === ws ? session.gateway : session.app;
        client.lastHeartbeat = Date.now();
        break;
      }
    }
  }

  private handleDisconnect(ws: WebSocket): void {
    console.log('[Relay] Connection closed');

    for (const [token, clients] of this.pendingClients.entries()) {
      const filtered = clients.filter(c => c.ws !== ws);
      if (filtered.length !== clients.length) {
        if (filtered.length > 0) {
          this.pendingClients.set(token, filtered);
        } else {
          this.pendingClients.delete(token);
        }
        break;
      }
    }

    for (const [token, session] of this.activeSessions.entries()) {
      if (session.gateway.ws === ws || session.app.ws === ws) {
        const peer = session.gateway.ws === ws ? session.app.ws : session.gateway.ws;
        if (peer.readyState === WebSocket.OPEN) {
          peer.send(JSON.stringify({ type: 'peer_disconnected' }));
          peer.close();
        }
        this.activeSessions.delete(token);
        console.log(`[Relay] Session terminated: token=${token.substring(0, 8)}...`);
        break;
      }
    }

    this.messageCounts.delete(ws);
  }

  private checkRateLimit(ws: WebSocket): boolean {
    const now = Date.now();
    let entry = this.messageCounts.get(ws);

    if (!entry || now > entry.resetAt) {
      entry = { count: 0, resetAt: now + this.RATE_LIMIT_WINDOW };
      this.messageCounts.set(ws, entry);
    }

    entry.count++;
    return entry.count <= this.RATE_LIMIT;
  }

  private sendError(ws: WebSocket, message: string): void {
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify({ type: 'error', message }));
    }
  }

  private startHeartbeatCheck(): void {
    this.heartbeatInterval = setInterval(() => {
      const now = Date.now();

      for (const [token, clients] of this.pendingClients.entries()) {
        const stale = clients.filter(c => now - c.lastHeartbeat > this.PENDING_TIMEOUT);
        for (const client of stale) {
          console.log(`[Relay] Timeout: pending client token=${token.substring(0, 8)}...`);
          client.ws.close();
        }
      }

      for (const [token, session] of this.activeSessions.entries()) {
        const gatewayStale = now - session.gateway.lastHeartbeat > this.HEARTBEAT_TIMEOUT;
        const appStale = now - session.app.lastHeartbeat > this.HEARTBEAT_TIMEOUT;

        if (gatewayStale || appStale) {
          console.log(`[Relay] Timeout: active session token=${token.substring(0, 8)}...`);
          session.gateway.ws.close();
          session.app.ws.close();
        }
      }
    }, this.HEARTBEAT_INTERVAL);
  }

  public stop(): void {
    if (this.heartbeatInterval) {
      clearInterval(this.heartbeatInterval);
    }
    this.wss.close();
    console.log('[Relay] Server stopped');
  }
}

const port = parseInt(process.env.RELAY_PORT || '8766', 10);
const server = new RelayServer(port);

process.on('SIGINT', () => {
  console.log('\n[Relay] Shutting down...');
  server.stop();
  process.exit(0);
});

process.on('SIGTERM', () => {
  console.log('\n[Relay] Shutting down...');
  server.stop();
  process.exit(0);
});