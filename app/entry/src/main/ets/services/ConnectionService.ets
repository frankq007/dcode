import { Connection } from '../models/index';
import { preferences } from '@kit.ArkData';

const CONNECTIONS_KEY = 'saved_connections';

export class ConnectionService {
  private connections: Map<string, Connection> = new Map();
  private prefs: preferences.Preferences | null = null;

  async init(context: Context): Promise<void> {
    try {
      this.prefs = await preferences.getPreferences(context, 'connections');
      await this.loadConnections();
    } catch (e) {
      console.error('[ConnectionService] Failed to init:', e);
    }
  }

  private async loadConnections(): Promise<void> {
    if (!this.prefs) return;

    try {
      const data = await this.prefs.get(CONNECTIONS_KEY, '[]');
      const connections: Connection[] = JSON.parse(data as string);
      for (let i = 0; i < connections.length; i++) {
        this.connections.set(connections[i].id, connections[i]);
      }
    } catch (e) {
      console.error('[ConnectionService] Failed to load connections:', e);
    }
  }

  private async saveConnections(): Promise<void> {
    if (!this.prefs) return;

    try {
      const connections = Array.from(this.connections.values());
      await this.prefs.put(CONNECTIONS_KEY, JSON.stringify(connections));
      await this.prefs.flush();
    } catch (e) {
      console.error('[ConnectionService] Failed to save connections:', e);
    }
  }

  getAll(): Connection[] {
    return Array.from(this.connections.values());
  }

  get(id: string): Connection | undefined {
    return this.connections.get(id);
  }

  async add(connection: Connection): Promise<void> {
    const ids = Array.from(this.connections.keys());
    for (let i = 0; i < ids.length; i++) {
      const existing = this.connections.get(ids[i]);
      if (existing &&
          existing.host === connection.host &&
          existing.port === connection.port &&
          existing.publicKey === connection.publicKey) {
        existing.name = connection.name;
        existing.isOnline = connection.isOnline;
        existing.lastConnected = connection.lastConnected;
        existing.token = connection.token;
        this.connections.set(ids[i], existing);
        await this.saveConnections();
        return;
      }
    }
    this.connections.set(connection.id, connection);
    await this.saveConnections();
  }

  async update(id: string, updates: Partial<Connection>): Promise<void> {
    const existing = this.connections.get(id);
    if (existing) {
      if (updates.id !== undefined) existing.id = updates.id;
      if (updates.name !== undefined) existing.name = updates.name;
      if (updates.mode !== undefined) existing.mode = updates.mode;
      if (updates.host !== undefined) existing.host = updates.host;
      if (updates.port !== undefined) existing.port = updates.port;
      if (updates.publicKey !== undefined) existing.publicKey = updates.publicKey;
      if (updates.token !== undefined) existing.token = updates.token;
      if (updates.relayUrl !== undefined) existing.relayUrl = updates.relayUrl;
      if (updates.isOnline !== undefined) existing.isOnline = updates.isOnline;
      if (updates.lastConnected !== undefined) existing.lastConnected = updates.lastConnected;
      this.connections.set(id, existing);
      await this.saveConnections();
    }
  }

  async delete(id: string): Promise<void> {
    this.connections.delete(id);
    await this.saveConnections();
  }

  async updateOnlineStatus(id: string, isOnline: boolean): Promise<void> {
    await this.update(id, { isOnline });
  }
}

export const connectionService = new ConnectionService();