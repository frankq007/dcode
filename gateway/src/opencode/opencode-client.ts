export interface OpencodeSessionInfo {
  id: string;
  slug: string;
  title: string;
  directory: string;
  path: string;
  version: string;
  time: { created: number; updated: number };
  tokens?: { input: number; output: number; reasoning: number; cache: { read: number; write: number } };
}

export interface OpencodeMessageInfo {
  id: string;
  sessionID: string;
  role: 'user' | 'assistant';
  time?: { created?: number; updated?: number; start?: number; end?: number; completed?: number };
  model?: { providerID: string; modelID: string };
  agent?: string;
  summary?: { diffs: any[] };
  finish?: string;
  cost?: number;
  tokens?: { total: number; input: number; output: number; reasoning: number; cache: { read: number; write: number } };
}

export interface OpencodePart {
  id: string;
  sessionID: string;
  messageID: string;
  type: 'text' | 'reasoning' | 'step-start' | 'step-finish' | 'patch' | 'tool' | string;
  text?: string;
  time?: { start: number; end: number };
  snapshot?: string;
  reason?: string;
  tokens?: { total: number; input: number; output: number; reasoning: number; cache: { read: number; write: number } };
  cost?: number;
  hash?: string;
  files?: string[];
  toolName?: string;
  input?: any;
  output?: any;
  [key: string]: any;
}

export interface OpencodeMessage {
  info: OpencodeMessageInfo;
  parts: OpencodePart[];
}

export type PartHandler = (part: OpencodePart, messageInfo: OpencodeMessageInfo) => void;

export class OpencodeClient {
  private baseUrl: string;

  constructor(baseUrl: string) {
    this.baseUrl = baseUrl.replace(/\/$/, '');
  }

  async createSession(): Promise<OpencodeSessionInfo> {
    const response = await fetch(`${this.baseUrl}/session`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: '{}'
    });

    if (!response.ok) {
      throw new Error(`Failed to create session: ${response.status} ${response.statusText}`);
    }

    const data = await response.json() as any;
    return data.info ? data.info : data;
  }

  async listSessions(): Promise<OpencodeSessionInfo[]> {
    const response = await fetch(`${this.baseUrl}/session`);

    if (!response.ok) {
      throw new Error(`Failed to list sessions: ${response.status} ${response.statusText}`);
    }

    const data = await response.json() as any;
    const sessions = Array.isArray(data) ? data : (data.sessions || []);
    return sessions.map((s: any) => s.info ? s.info : s);
  }

  async deleteSession(id: string): Promise<void> {
    const response = await fetch(`${this.baseUrl}/session/${id}`, {
      method: 'DELETE'
    });

    if (!response.ok) {
      throw new Error(`Failed to delete session: ${response.status} ${response.statusText}`);
    }
  }

  async getMessages(sessionId: string): Promise<OpencodeMessage[]> {
    const response = await fetch(`${this.baseUrl}/session/${sessionId}/message`);

    if (!response.ok) {
      throw new Error(`Failed to get messages: ${response.status} ${response.statusText}`);
    }

    const data = await response.json() as any;
    return Array.isArray(data) ? data : [];
  }

  async sendMessage(sessionId: string, text: string, onPart?: PartHandler): Promise<OpencodeMessage> {
    const response = await fetch(`${this.baseUrl}/session/${sessionId}/message`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ parts: [{ type: 'text', text }] })
    });

    if (!response.ok) {
      throw new Error(`Failed to send message: ${response.status} ${response.statusText}`);
    }

    const data = await response.json() as any;
    const message: OpencodeMessage = { info: data.info, parts: data.parts || [] };

    if (onPart) {
      for (const part of message.parts) {
        onPart(part, message.info);
      }
    }

    return message;
  }

  async respondPermission(permissionId: string, allow: boolean): Promise<void> {
    const response = await fetch(`${this.baseUrl}/permission/${permissionId}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ allow })
    });

    if (!response.ok) {
      throw new Error(`Failed to respond to permission: ${response.status} ${response.statusText}`);
    }
  }

  async getPermissions(): Promise<any[]> {
    const response = await fetch(`${this.baseUrl}/permission`);
    if (!response.ok) return [];
    const data = await response.json();
    return Array.isArray(data) ? data : [];
  }

  async getConfig(): Promise<any> {
    const response = await fetch(`${this.baseUrl}/config`);
    if (!response.ok) {
      throw new Error(`Failed to get config: ${response.status} ${response.statusText}`);
    }
    return response.json();
  }

  async getVersion(): Promise<string> {
    try {
      const session = await this.createSession();
      await this.deleteSession(session.id);
      return session.version || 'unknown';
    } catch {
      try {
        const response = await fetch(`${this.baseUrl}/config`);
        if (response.ok) {
          const data = await response.json() as any;
          return data.version || 'unknown';
        }
      } catch {
        // ignore
      }
      return 'unknown';
    }
  }
}
