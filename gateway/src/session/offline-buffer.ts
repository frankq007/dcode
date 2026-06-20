import { Message } from '../types';

const EVENT_TYPES = new Set<string>([
  'reply',
  'thinking',
  'tool_call',
  'token_info',
  'permission_request',
  'review_url'
]);

interface BufferedEvent {
  seq: number;
  message: Message;
}

export class OfflineEventBuffer {
  private buffers: Map<string, BufferedEvent[]> = new Map();
  private seqCounters: Map<string, number> = new Map();
  private readonly maxBuffer: number;

  constructor(maxBuffer: number = 500) {
    this.maxBuffer = maxBuffer;
  }

  isEventType(type: string): boolean {
    return EVENT_TYPES.has(type);
  }

  nextSeq(sessionId: string): number {
    const current = this.seqCounters.get(sessionId) || 0;
    const next = current + 1;
    this.seqCounters.set(sessionId, next);
    return next;
  }

  store(sessionId: string, message: Message): void {
    let buf = this.buffers.get(sessionId);
    if (!buf) {
      buf = [];
      this.buffers.set(sessionId, buf);
    }
    buf.push({ seq: message.seq!, message });
    if (buf.length > this.maxBuffer) {
      buf.shift();
    }
  }

  since(sessionId: string, lastSeq: number): Message[] {
    const buf = this.buffers.get(sessionId);
    if (!buf) return [];
    return buf.filter((e) => e.seq > lastSeq).map((e) => e.message);
  }

  getSeq(sessionId: string): number {
    return this.seqCounters.get(sessionId) || 0;
  }

  clearSession(sessionId: string): void {
    this.buffers.delete(sessionId);
    this.seqCounters.delete(sessionId);
  }

  clearAll(): void {
    this.buffers.clear();
    this.seqCounters.clear();
  }
}
