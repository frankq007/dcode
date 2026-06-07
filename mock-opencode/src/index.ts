import { createServer, IncomingMessage, ServerResponse } from 'http';
import { randomUUID } from 'crypto';

interface Session {
  id: string;
  name: string;
  messages: any[];
}

const sessions: Map<string, Session> = new Map();
const PORT = parseInt(process.env.PORT || '3000', 10);

function handleRequest(req: IncomingMessage, res: ServerResponse): void {
  const url = new URL(req.url || '/', `http://localhost:${PORT}`);
  const path = url.pathname;
  const method = req.method || 'GET';

  res.setHeader('Content-Type', 'application/json');
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  // Create session
  if (method === 'POST' && path === '/sessions') {
    const id = randomUUID();
    const session: Session = {
      id,
      name: `Session ${sessions.size + 1}`,
      messages: []
    };
    sessions.set(id, session);
    
    console.log(`[MockOpencode] Created session: ${id}`);
    
    res.writeHead(201);
    res.end(JSON.stringify({ id, name: session.name }));
    return;
  }

  // List sessions
  if (method === 'GET' && path === '/sessions') {
    const list = Array.from(sessions.values()).map(s => ({ id: s.id, name: s.name }));
    res.writeHead(200);
    res.end(JSON.stringify(list));
    return;
  }

  // Delete session
  const deleteMatch = path.match(/^\/sessions\/([^/]+)$/);
  if (method === 'DELETE' && deleteMatch) {
    const sessionId = decodeURIComponent(deleteMatch[1]);
    sessions.delete(sessionId);
    console.log(`[MockOpencode] Deleted session: ${sessionId}`);
    res.writeHead(204);
    res.end();
    return;
  }

  // Send message (SSE stream)
  const messageMatch = path.match(/^\/sessions\/([^/]+)\/messages$/);
  if (method === 'POST' && messageMatch) {
    const sessionId = decodeURIComponent(messageMatch[1]);
    const session = sessions.get(sessionId);
    
    if (!session) {
      res.writeHead(404);
      res.end(JSON.stringify({ error: 'Session not found' }));
      return;
    }

    let body = '';
    req.on('data', chunk => body += chunk);
    req.on('end', () => {
      const { content } = JSON.parse(body || '{}');
      console.log(`[MockOpencode] Message in session ${sessionId}: ${content}`);
      
      session.messages.push({ role: 'user', content });
      res.writeHead(200);
      res.end(JSON.stringify({ status: 'ok' }));
      
      // Simulate SSE events after a delay
      setTimeout(() => {
        console.log(`[MockOpencode] Simulating response for session ${sessionId}`);
      }, 500);
    });
    return;
  }

  // SSE events stream
  const eventsMatch = path.match(/^\/sessions\/([^/]+)\/events$/);
  if (method === 'GET' && eventsMatch) {
    const sessionId = decodeURIComponent(eventsMatch[1]);
    const session = sessions.get(sessionId);
    
    if (!session) {
      res.writeHead(404);
      res.end(JSON.stringify({ error: 'Session not found' }));
      return;
    }

    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');
    res.writeHead(200);

    // Send thinking event
    setTimeout(() => {
      res.write(`data: ${JSON.stringify({ type: 'thinking', data: { content: 'Analyzing your request...' } })}\n\n`);
    }, 300);

    // Send tool call event
    setTimeout(() => {
      res.write(`data: ${JSON.stringify({ type: 'tool_call', data: { toolName: 'file_read', parameters: { path: '/example.ts' }, result: 'File contents read successfully' } })}\n\n`);
    }, 800);

    // Send reply event
    setTimeout(() => {
      res.write(`data: ${JSON.stringify({ type: 'reply', data: { content: 'Hello! I am the mock opencode server. I received your message and this is a simulated response.\n\n```typescript\nconsole.log("Hello, World!");\n```' } })}\n\n`);
    }, 1200);

    // Send token usage event
    setTimeout(() => {
      res.write(`data: ${JSON.stringify({ type: 'token_usage', data: { input: 150, output: 50, total: 200, contextWindow: 4096 } })}\n\n`);
    }, 1400);

    // Keep connection open for a bit, then close
    setTimeout(() => {
      res.end();
    }, 2000);

    return;
  }

  // Token usage
  const tokenMatch = path.match(/^\/sessions\/([^/]+)\/tokens$/);
  if (method === 'GET' && tokenMatch) {
    res.writeHead(200);
    res.end(JSON.stringify({ input: 150, output: 50, total: 200, contextWindow: 4096 }));
    return;
  }

  // Permission handling
  const permMatch = path.match(/^\/sessions\/([^/]+)\/permissions\/([^/]+)$/);
  if (method === 'POST' && permMatch) {
    let body = '';
    req.on('data', chunk => body += chunk);
    req.on('end', () => {
      const { allowed } = JSON.parse(body || '{}');
      console.log(`[MockOpencode] Permission reply: ${allowed ? 'allowed' : 'denied'}`);
      res.writeHead(200);
      res.end(JSON.stringify({ status: 'ok' }));
    });
    return;
  }

  // Review URL
  if (method === 'GET' && path === '/review/url') {
    res.writeHead(200);
    res.end(JSON.stringify({ url: 'https://example.com/review' }));
    return;
  }

  // Health check
  if (method === 'GET' && path === '/health') {
    res.writeHead(200);
    res.end(JSON.stringify({ status: 'ok', sessions: sessions.size }));
    return;
  }

  // 404
  res.writeHead(404);
  res.end(JSON.stringify({ error: 'Not found' }));
}

const server = createServer(handleRequest);

server.listen(PORT, () => {
  console.log(`[MockOpencode] Server running on http://localhost:${PORT}`);
  console.log(`[MockOpencode] Available endpoints:`);
  console.log(`  POST   /sessions          - Create session`);
  console.log(`  GET    /sessions          - List sessions`);
  console.log(`  DELETE /sessions/:id      - Delete session`);
  console.log(`  POST   /sessions/:id/messages - Send message`);
  console.log(`  GET    /sessions/:id/events   - SSE event stream`);
  console.log(`  GET    /sessions/:id/tokens   - Token usage`);
  console.log(`  POST   /sessions/:id/permissions/:reqId - Permission reply`);
  console.log(`  GET    /review/url        - Get review URL`);
  console.log(`  GET    /health            - Health check`);
});

process.on('SIGINT', () => {
  console.log('\n[MockOpencode] Shutting down...');
  server.close();
  process.exit(0);
});
