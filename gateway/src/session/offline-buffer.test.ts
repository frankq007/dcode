import { describe, it, expect, beforeEach } from 'vitest';
import { OfflineEventBuffer } from './offline-buffer';
import { Message } from '../types';

function makeMessage(type: string, id: string, seq?: number): Message {
  return {
    type: type as any,
    id,
    seq,
    data: { content: `content-${id}` },
    timestamp: Date.now()
  };
}

describe('OfflineEventBuffer', () => {
  let buffer: OfflineEventBuffer;

  beforeEach(() => {
    buffer = new OfflineEventBuffer(5);
  });

  it('should identify event types correctly', () => {
    expect(buffer.isEventType('reply')).toBe(true);
    expect(buffer.isEventType('thinking')).toBe(true);
    expect(buffer.isEventType('tool_call')).toBe(true);
    expect(buffer.isEventType('token_info')).toBe(true);
    expect(buffer.isEventType('permission_request')).toBe(true);
    expect(buffer.isEventType('review_url')).toBe(true);

    expect(buffer.isEventType('session_list')).toBe(false);
    expect(buffer.isEventType('history')).toBe(false);
    expect(buffer.isEventType('message_ack')).toBe(false);
    expect(buffer.isEventType('heartbeat')).toBe(false);
  });

  it('should assign monotonically increasing seq per session', () => {
    expect(buffer.nextSeq('s1')).toBe(1);
    expect(buffer.nextSeq('s1')).toBe(2);
    expect(buffer.nextSeq('s1')).toBe(3);

    expect(buffer.nextSeq('s2')).toBe(1);
    expect(buffer.nextSeq('s2')).toBe(2);

    expect(buffer.nextSeq('s1')).toBe(4);
  });

  it('should get current seq (0 when no events stored)', () => {
    expect(buffer.getSeq('s1')).toBe(0);
    buffer.nextSeq('s1');
    expect(buffer.getSeq('s1')).toBe(1);
  });

  it('should store and replay events since a given seq', () => {
    const sessionId = 's1';
    const m1 = makeMessage('reply', 'r1', buffer.nextSeq(sessionId));
    const m2 = makeMessage('thinking', 't1', buffer.nextSeq(sessionId));
    const m3 = makeMessage('reply', 'r2', buffer.nextSeq(sessionId));

    buffer.store(sessionId, m1);
    buffer.store(sessionId, m2);
    buffer.store(sessionId, m3);

    const since0 = buffer.since(sessionId, 0);
    expect(since0.length).toBe(3);
    expect(since0[0].id).toBe('r1');
    expect(since0[2].id).toBe('r2');

    const since1 = buffer.since(sessionId, 1);
    expect(since1.length).toBe(2);
    expect(since1[0].id).toBe('t1');
    expect(since1[1].id).toBe('r2');

    const since3 = buffer.since(sessionId, 3);
    expect(since3.length).toBe(0);
  });

  it('should keep separate buffers per session', () => {
    buffer.store('s1', makeMessage('reply', 'a', buffer.nextSeq('s1')));
    buffer.store('s2', makeMessage('reply', 'b', buffer.nextSeq('s2')));
    buffer.store('s2', makeMessage('reply', 'c', buffer.nextSeq('s2')));

    expect(buffer.since('s1', 0).length).toBe(1);
    expect(buffer.since('s2', 0).length).toBe(2);
  });

  it('should return empty array for unknown session', () => {
    expect(buffer.since('unknown', 0)).toEqual([]);
  });

  it('should evict oldest events when exceeding max buffer size', () => {
    const sessionId = 's1';
    for (let i = 1; i <= 7; i++) {
      const msg = makeMessage('reply', `r${i}`, buffer.nextSeq(sessionId));
      buffer.store(sessionId, msg);
    }

    const since0 = buffer.since(sessionId, 0);
    expect(since0.length).toBe(5);
    expect(since0[0].id).toBe('r3');
    expect(since0[4].id).toBe('r7');
  });

  it('should replay nothing when lastSeq covers all stored events', () => {
    const sessionId = 's1';
    buffer.store(sessionId, makeMessage('reply', 'r1', buffer.nextSeq(sessionId)));
    buffer.store(sessionId, makeMessage('reply', 'r2', buffer.nextSeq(sessionId)));

    expect(buffer.since(sessionId, 2)).toEqual([]);
  });

  it('should clear a single session', () => {
    buffer.store('s1', makeMessage('reply', 'a', buffer.nextSeq('s1')));
    buffer.store('s2', makeMessage('reply', 'b', buffer.nextSeq('s2')));

    buffer.clearSession('s1');

    expect(buffer.since('s1', 0)).toEqual([]);
    expect(buffer.since('s2', 0).length).toBe(1);
    expect(buffer.getSeq('s1')).toBe(0);
    expect(buffer.getSeq('s2')).toBe(1);
  });

  it('should clear all sessions', () => {
    buffer.store('s1', makeMessage('reply', 'a', buffer.nextSeq('s1')));
    buffer.store('s2', makeMessage('reply', 'b', buffer.nextSeq('s2')));

    buffer.clearAll();

    expect(buffer.since('s1', 0)).toEqual([]);
    expect(buffer.since('s2', 0)).toEqual([]);
    expect(buffer.getSeq('s1')).toBe(0);
    expect(buffer.getSeq('s2')).toBe(0);
  });

  it('should handle seq wrap by filtering strictly greater than', () => {
    const sessionId = 's1';
    buffer.store(sessionId, makeMessage('reply', 'r1', buffer.nextSeq(sessionId)));

    const replayed = buffer.since(sessionId, 0);
    expect(replayed.length).toBe(1);
    expect(replayed[0].seq).toBe(1);
  });
});
