import { Message } from '../types';

export interface OpencodeEvent {
  type: string;
  data: any;
}

export class OpencodeClient {
  private baseUrl: string;
  private eventListeners: Map<string, ((event: OpencodeEvent) => void)[]> = new Map();

  constructor(baseUrl: string) {
    this.baseUrl = baseUrl.replace(/\/$/, '');
  }

  async sendMessage(sessionId: string, message: string): Promise<void> {
    const response = await fetch(`${this.baseUrl}/sessions/${sessionId}/messages`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ content: message })
    });
    
    if (!response.ok) {
      throw new Error(`Failed to send message: ${response.statusText}`);
    }
  }

  subscribeToEvents(sessionId: string, onEvent: (event: OpencodeEvent) => void): AbortController {
    const controller = new AbortController();
    
    this.connectSSE(sessionId, onEvent, controller.signal);
    
    return controller;
  }

  private async connectSSE(sessionId: string, onEvent: (event: OpencodeEvent) => void, signal: AbortSignal): Promise<void> {
    try {
      const response = await fetch(`${this.baseUrl}/sessions/${sessionId}/events`, {
        signal,
        headers: { 'Accept': 'text/event-stream' }
      });

      if (!response.ok) {
        throw new Error(`SSE connection failed: ${response.statusText}`);
      }

      const reader = response.body?.getReader();
      if (!reader) throw new Error('No response body');

      const decoder = new TextDecoder();
      let buffer = '';

      while (!signal.aborted) {
        const { done, value } = await reader.read();
        if (done) break;

        buffer += decoder.decode(value, { stream: true });
        const lines = buffer.split('\n');
        buffer = lines.pop() || '';

        for (const line of lines) {
          if (line.startsWith('data: ')) {
            try {
              const event = JSON.parse(line.slice(6));
              onEvent(event);
            } catch (e) {
              console.error('[Opencode] Failed to parse SSE event:', e);
            }
          }
        }
      }
    } catch (e: any) {
      if (e.name !== 'AbortError') {
        console.error('[Opencode] SSE error:', e.message);
      }
    }
  }

  async createSession(): Promise<{ id: string }> {
    const response = await fetch(`${this.baseUrl}/sessions`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' }
    });
    
    if (!response.ok) {
      throw new Error(`Failed to create session: ${response.statusText}`);
    }
    
    return response.json() as Promise<{ id: string }>;
  }

  async listSessions(): Promise<Array<{ id: string; name: string }>> {
    const response = await fetch(`${this.baseUrl}/sessions`);
    
    if (!response.ok) {
      throw new Error(`Failed to list sessions: ${response.statusText}`);
    }
    
    return response.json() as Promise<Array<{ id: string; name: string }>>;
  }

  async deleteSession(id: string): Promise<void> {
    const response = await fetch(`${this.baseUrl}/sessions/${id}`, {
      method: 'DELETE'
    });
    
    if (!response.ok) {
      throw new Error(`Failed to delete session: ${response.statusText}`);
    }
  }

  async getReviewUrl(): Promise<string> {
    const response = await fetch(`${this.baseUrl}/review/url`);
    
    if (!response.ok) {
      throw new Error(`Failed to get review URL: ${response.statusText}`);
    }
    
    const data = await response.json() as { url: string };
    return data.url;
  }

  async getTokenUsage(sessionId: string): Promise<{ input: number; output: number; total: number; contextWindow: number }> {
    const response = await fetch(`${this.baseUrl}/sessions/${sessionId}/tokens`);
    
    if (!response.ok) {
      throw new Error(`Failed to get token usage: ${response.statusText}`);
    }
    
    return response.json() as Promise<{ input: number; output: number; total: number; contextWindow: number }>;
  }

  async handlePermissionReply(sessionId: string, requestId: string, allowed: boolean): Promise<void> {
    const response = await fetch(`${this.baseUrl}/sessions/${sessionId}/permissions/${requestId}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ allowed })
    });
    
    if (!response.ok) {
      throw new Error(`Failed to send permission reply: ${response.statusText}`);
    }
  }
}
