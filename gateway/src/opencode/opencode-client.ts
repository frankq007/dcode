export interface OpencodeSessionInfo {
  id: string;
  slug: string;
  title: string;
  directory: string;
  path: string;
  version: string;
  parentID?: string;
  time: { created: number; updated: number; archived?: number };
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
    const sessions = Array.isArray(data) ? data : (data.value || data.sessions || []);
    return sessions.map((s: any) => s.info ? s.info : s).filter((s: OpencodeSessionInfo) => !s.parentID);
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
    const response = await fetch(`${this.baseUrl}/session/${sessionId}/message?subscribe=true`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Accept': 'text/event-stream' },
      body: JSON.stringify({ parts: [{ type: 'text', text }] })
    });

    if (!response.ok) {
      throw new Error(`Failed to send message: ${response.status} ${response.statusText}`);
    }

    const contentType = response.headers.get('content-type') || '';
    const fullMessage: OpencodeMessage = { info: {} as any, parts: [] };

    if (response.body && (contentType.includes('text/event-stream') || response.headers.get('transfer-encoding') === 'chunked')) {
      const reader = response.body.getReader();
      const decoder = new TextDecoder();
      let buffer = '';

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        buffer += decoder.decode(value, { stream: true });

        if (contentType.includes('text/event-stream')) {
          const lines = buffer.split('\n');
          buffer = lines.pop() || '';
          for (const line of lines) {
            if (line.startsWith('data: ')) {
              const jsonStr = line.slice(6).trim();
              if (!jsonStr) continue;
              try {
                const event = JSON.parse(jsonStr) as any;
                if (event.type === 'message' || event.info) {
                  fullMessage.info = event.info || event.data?.info || {} as any;
                  fullMessage.parts = event.parts || event.data?.parts || [];
                } else if ((event.type === 'part' && event.part) || event.part) {
                  const part = event.part || event;
                  if (onPart) onPart(part, fullMessage.info);
                  if (!fullMessage.parts.includes(part)) fullMessage.parts.push(part);
                }
              } catch {
                // partial JSON, wait for more data
              }
            }
          }
        } else {
          const parsed = this.tryParseStreamedJson(buffer, onPart, fullMessage);
          if (parsed.consumed > 0) {
            buffer = buffer.slice(parsed.consumed);
          }
        }
      }

      if (!contentType.includes('text/event-stream') && buffer.trim()) {
        try {
          const data = JSON.parse(buffer) as any;
          fullMessage.info = data.info || {};
          fullMessage.parts = data.parts || [];
          if (onPart) {
            for (const part of fullMessage.parts) {
              onPart(part, fullMessage.info);
            }
          }
        } catch {
          // already processed via streaming
        }
      }

      return fullMessage;
    } else {
      const data = await response.json() as any;
      fullMessage.info = data.info || {};
      fullMessage.parts = data.parts || [];
      if (onPart) {
        for (const part of fullMessage.parts) {
          onPart(part, fullMessage.info);
        }
      }
      return fullMessage;
    }
  }

  private tryParseStreamedJson(buffer: string, onPart: ((part: OpencodePart, msgInfo: OpencodeMessageInfo) => void) | undefined, fullMessage: OpencodeMessage): { consumed: number } {
    const partMarker = '"type":"';
    let searchFrom = 0;
    let lastConsumed = 0;

    while (true) {
      const idx = buffer.indexOf(partMarker, searchFrom);
      if (idx === -1) break;

      const partStart = buffer.lastIndexOf('{', idx);
      if (partStart === -1) break;

      let depth = 0;
      let endIdx = -1;
      let inString = false;
      let escape = false;

      for (let i = partStart; i < buffer.length; i++) {
        const ch = buffer[i];
        if (escape) { escape = false; continue; }
        if (ch === '\\') { escape = true; continue; }
        if (ch === '"') { inString = !inString; continue; }
        if (inString) continue;
        if (ch === '{') depth++;
        if (ch === '}') { depth--; if (depth === 0) { endIdx = i; break; } }
      }

      if (endIdx === -1) break;

      const partJson = buffer.substring(partStart, endIdx + 1);
      try {
        const part = JSON.parse(partJson) as any;
        if (part.type && part.id) {
          if (onPart) onPart(part as OpencodePart, fullMessage.info);
          if (!fullMessage.parts.find(p => p.id === part.id)) {
            fullMessage.parts.push(part as OpencodePart);
          }
          lastConsumed = endIdx + 1;
        }
      } catch {
        // not a valid complete part yet
      }

      searchFrom = endIdx + 1;
    }

    return { consumed: lastConsumed };
  }

  async sendMessageStream(sessionId: string, text: string, onPart?: PartHandler): Promise<OpencodeMessage> {
    const response = await fetch(`${this.baseUrl}/session/${sessionId}/message?subscribe=true`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Accept': 'text/event-stream' },
      body: JSON.stringify({ parts: [{ type: 'text', text }] })
    });

    if (!response.ok) {
      throw new Error(`Failed to send message: ${response.status} ${response.statusText}`);
    }

    const contentType = response.headers.get('content-type') || '';

    if (contentType.includes('text/event-stream') && response.body) {
      const reader = response.body.getReader();
      const decoder = new TextDecoder();
      let buffer = '';
      let fullMessage: OpencodeMessage = { info: {} as any, parts: [] };

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        buffer += decoder.decode(value, { stream: true });
        const lines = buffer.split('\n');
        buffer = lines.pop() || '';

        for (const line of lines) {
          if (line.startsWith('data: ')) {
            const jsonStr = line.slice(6).trim();
            if (!jsonStr) continue;
            try {
              const event = JSON.parse(jsonStr) as any;
              if (event.type === 'message' || event.info) {
                fullMessage = { info: event.info || event.data?.info || {} as any, parts: event.parts || event.data?.parts || [] };
              } else if (event.type === 'part' && event.part && onPart) {
                onPart(event.part, fullMessage.info);
              } else if (event.part && onPart) {
                onPart(event.part, fullMessage.info);
              }
            } catch {
              // ignore parse errors for partial events
            }
          }
        }
      }
      return fullMessage;
    } else {
      const data = await response.json() as any;
      const message: OpencodeMessage = { info: data.info, parts: data.parts || [] };
      if (onPart) {
        for (const part of message.parts) {
          onPart(part, message.info);
        }
      }
      return message;
    }
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
