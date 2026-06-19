import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import http, { createServer, IncomingMessage, ClientRequest } from 'http';
import { handleRequest } from './index';

const TEST_PORT = 3099;
const BASE = `http://localhost:${TEST_PORT}`;

let testServer: import('http').Server;

beforeAll(async () => {
  testServer = createServer(handleRequest);
  await new Promise<void>((resolve) => {
    testServer.listen(TEST_PORT, resolve);
  });
});

afterAll(async () => {
  await new Promise<void>((resolve) => {
    testServer.closeAllConnections();
    testServer.close(() => resolve());
  });
});

async function api(path: string, options: RequestInit = {}): Promise<Response> {
  return fetch(`${BASE}${path}`, options);
}

async function createSession(): Promise<any> {
  const res = await api('/session', { method: 'POST' });
  expect(res.ok).toBe(true);
  return res.json();
}

describe('mock-opencode (aligned with real opencode serve API)', () => {
  it('should return config with version', async () => {
    const res = await api('/config');
    const data = await res.json() as any;
    expect(res.ok).toBe(true);
    expect(data.version).toBeDefined();
  });

  it('should create session via POST /session', async () => {
    const session = await createSession();
    expect(session.id).toBeDefined();
    expect(session.id.startsWith('ses_')).toBe(true);
    expect(session.title).toBeDefined();
  });

  it('should list sessions via GET /session', async () => {
    await createSession();
    const res = await api('/session');
    const list = await res.json() as any[];
    expect(Array.isArray(list)).toBe(true);
    expect(list.length).toBeGreaterThan(0);
    expect(list[0].id).toBeDefined();
  });

  it('should send message via POST /session/:id/message and get {info, parts}', async () => {
    const session = await createSession();

    const res = await api(`/session/${session.id}/message`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ parts: [{ type: 'text', text: 'Hello mock' }] })
    });

    expect(res.ok).toBe(true);
    const msg = await res.json() as any;

    // Verify real opencode message structure
    expect(msg.info).toBeDefined();
    expect(msg.info.role).toBe('assistant');
    expect(msg.info.id).toBeDefined();
    expect(msg.parts).toBeDefined();
    expect(Array.isArray(msg.parts)).toBe(true);

    // Verify part types
    const partTypes = msg.parts.map((p: any) => p.type);
    expect(partTypes).toContain('step-start');
    expect(partTypes).toContain('reasoning');
    expect(partTypes).toContain('text');
    expect(partTypes).toContain('step-finish');
  });

  it('should send message with subscribe=true and receive chunked response', async () => {
    const session = await createSession();

    const res = await api(`/session/${session.id}/message?subscribe=true`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ parts: [{ type: 'text', text: 'Stream test' }] })
    });

    expect(res.ok).toBe(true);
    const text = await res.text();
    expect(text.length).toBeGreaterThan(0);

    // The chunked response should contain valid JSON when concatenated
    const msg = JSON.parse(text) as any;
    expect(msg.info).toBeDefined();
    expect(msg.parts).toBeDefined();
    expect(msg.parts.length).toBeGreaterThan(0);
  });

  it('should get message history via GET /session/:id/message', async () => {
    const session = await createSession();

    // Send a message first
    await api(`/session/${session.id}/message`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ parts: [{ type: 'text', text: 'History test' }] })
    });

    // Get history
    const res = await api(`/session/${session.id}/message`);
    const msgs = await res.json() as any[];

    expect(Array.isArray(msgs)).toBe(true);
    expect(msgs.length).toBe(2); // user + assistant

    // Verify user message structure
    const userMsg = msgs[0];
    expect(userMsg.info.role).toBe('user');
    expect(userMsg.parts[0].type).toBe('text');
    expect(userMsg.parts[0].text).toBe('History test');

    // Verify assistant message structure
    const assistantMsg = msgs[1];
    expect(assistantMsg.info.role).toBe('assistant');
  });

  it('should delete session via DELETE /session/:id', async () => {
    const session = await createSession();
    const res = await api(`/session/${session.id}`, { method: 'DELETE' });
    expect(res.ok).toBe(true);

    const listRes = await api('/session');
    const list = await listRes.json() as any[];
    expect(list.find((s: any) => s.id === session.id)).toBeUndefined();
  });

  it('should return 404 for non-existent session', async () => {
    const res = await api('/session/non-existent-id/message');
    expect(res.status).toBe(404);
  });

  it('should handle permission GET and POST', async () => {
    const listRes = await api('/permission');
    expect(listRes.ok).toBe(true);
    const list = await listRes.json() as any[];
    expect(Array.isArray(list)).toBe(true);

    const postRes = await api('/permission/test-id', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ allow: true })
    });
    expect(postRes.ok).toBe(true);
  });
});
