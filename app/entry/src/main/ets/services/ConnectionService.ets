import { Connection } from '../models/index';

const CONNECTIONS_KEY = 'saved_connections';

export class ConnectionService {
  private connections: Map<string, Connection> = new Map();
  private preferences: preferences.Preferences | null = null;

  async init(context: Context): Promise<void> {
    try {
      this.preferences = await preferences.getPreferences(context, 'connections');
      await this.loadConnections();
    } catch (e) {
      console.error('[ConnectionService] Failed to init:', e);
    }
  }

  private async loadConnections(): Promise<void> {
    if (!this.preferences) return;
    
    try {
      const data = await this.preferences.get(CONNECTIONS_KEY, '[]');
      const connections: Connection[] = JSON.parse(data as string);
      connections.forEach(conn => this.connections.set(conn.id, conn));
    } catch (e) {
      console.error('[ConnectionService] Failed to load connections:', e);
    }
  }

  private async saveConnections(): Promise<void> {
    if (!this.preferences) return;
    
    try {
      const connections = Array.from(this.connections.values());
      await this.preferences.put(CONNECTIONS_KEY, JSON.stringify(connections));
      await this.preferences.flush();
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
    this.connections.set(connection.id, connection);
    await this.saveConnections();
  }

  async update(id: string, updates: Partial<Connection>): Promise<void> {
    const existing = this.connections.get(id);
    if (existing) {
      const updated = { ...existing, ...updates };
      this.connections.set(id, updated);
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
