import { randomUUID } from 'crypto';

export interface Session {
  id: string;
  name: string;
  createdAt: number;
  lastActivity: number;
}

export class SessionManager {
  private sessions: Map<string, Session> = new Map();
  private activeSessionId: string | null = null;

  create(name?: string): Session {
    const session: Session = {
      id: randomUUID(),
      name: name || `Session ${this.sessions.size + 1}`,
      createdAt: Date.now(),
      lastActivity: Date.now()
    };
    this.sessions.set(session.id, session);
    this.activeSessionId = session.id;
    console.log(`[Session] Created: ${session.name} (${session.id})`);
    return session;
  }

  get(id: string): Session | undefined {
    return this.sessions.get(id);
  }

  list(): Session[] {
    return Array.from(this.sessions.values());
  }

  getActive(): Session | null {
    if (!this.activeSessionId) return null;
    return this.sessions.get(this.activeSessionId) || null;
  }

  switch(id: string): Session | null {
    const session = this.sessions.get(id);
    if (session) {
      this.activeSessionId = id;
      session.lastActivity = Date.now();
      console.log(`[Session] Switched to: ${session.name}`);
      return session;
    }
    return null;
  }

  delete(id: string): boolean {
    const result = this.sessions.delete(id);
    if (result && this.activeSessionId === id) {
      const firstKey = this.sessions.keys().next().value;
      this.activeSessionId = firstKey !== undefined ? firstKey : null;
    }
    return result;
  }

  touch(id: string): void {
    const session = this.sessions.get(id);
    if (session) {
      session.lastActivity = Date.now();
    }
  }
}
