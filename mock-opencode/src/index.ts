import { createServer, IncomingMessage, ServerResponse } from 'http';
import { randomBytes } from 'crypto';

interface MockSession {
  id: string;
  slug: string;
  title: string;
  directory: string;
  path: string;
  version: string;
  time: { created: number; updated: number };
  tokens: { input: number; output: number; reasoning: number; cache: { read: number; write: number } };
}

interface MockPart {
  id: string;
  sessionID: string;
  messageID: string;
  type: string;
  text?: string;
  time?: { start: number; end: number };
  reason?: string;
  tokens?: { total: number; input: number; output: number; reasoning: number; cache: { read: number; write: number } };
  cost?: number;
  snapshot?: string;
  toolName?: string;
  input?: any;
  output?: any;
  [key: string]: any;
}

interface MockMessage {
  info: {
    id: string;
    sessionID: string;
    role: 'user' | 'assistant';
    time: { created: number; completed?: number; updated?: number };
    model?: { providerID: string; modelID: string };
    agent?: string;
    finish?: string;
    cost?: number;
    tokens?: { total: number; input: number; output: number; reasoning: number; cache: { read: number; write: number } };
  };
  parts: MockPart[];
}

const sessions = new Map<string, MockSession>();
const messages = new Map<string, MockMessage[]>();
const PORT = parseInt(process.env.PORT || '3000', 10);
const MOCK_VERSION = '1.17.8-mock';
const MODEL = { providerID: 'mock', modelID: 'mock-gpt' };

function generateID(prefix: string): string {
  return `${prefix}_${randomBytes(12).toString('hex')}`;
}

function createSessionObj(): MockSession {
  const slugs = ['quiet-orchid', 'crisp-island', 'amber-river', 'swift-forest', 'bold-summit'];
  const slug = `${slugs[Math.floor(Math.random() * slugs.length)]}-${Date.now().toString(36)}`;
  return {
    id: generateID('ses'),
    slug,
    title: `New session - ${new Date().toISOString()}`,
    directory: process.cwd(),
    path: '',
    version: MOCK_VERSION,
    time: { created: Date.now(), updated: Date.now() },
    tokens: { input: 0, output: 0, reasoning: 0, cache: { read: 0, write: 0 } }
  };
}

function generateAssistantParts(sessionId: string, userText: string): { parts: MockPart[]; tokens: any } {
  const messageID = generateID('msg');
  const now = Date.now();
  const inputTokens = 50 + userText.length;
  const lower = userText.toLowerCase();

  const parts: MockPart[] = [];

  parts.push({
    id: generateID('prt'), sessionID: sessionId, messageID, type: 'step-start',
    snapshot: randomBytes(20).toString('hex')
  });

  const thinkingText = lower.includes('mermaid')
    ? '用户请求图表，我将使用 Mermaid 语法绘制。'
    : `正在分析用户请求："${userText}"`;
  parts.push({
    id: generateID('prt'), sessionID: sessionId, messageID, type: 'reasoning',
    text: thinkingText,
    time: { start: now, end: now + 100 }
  });

  if (lower.includes('mermaid') || lower.includes('图表')) {
    parts.push({
      id: generateID('prt'), sessionID: sessionId, messageID, type: 'tool',
      toolName: 'diagram_generate',
      input: { type: 'flowchart' },
      output: { status: 'ok' },
      time: { start: now + 200, end: now + 500 }
    });
  }

  const replyText = lower.includes('mermaid')
    ? '这是一个流程图：\n\n```mermaid\ngraph TD\n  A[开始] --> B{条件}\n  B -->|是| C[执行]\n  B -->|否| D[跳过]\n  C --> E[结束]\n  D --> E\n```'
    : `收到您的消息："${userText}"\n\n这是一段 **Markdown** 示例：\n\n- 列表项 1\n- 列表项 2\n\n\`\`\`typescript\nfunction greet(n: string): string {\n  return \`Hello, \${n}!\`;\n}\n\`\`\`\n`;

  parts.push({
    id: generateID('prt'), sessionID: sessionId, messageID, type: 'text',
    text: replyText,
    time: { start: now + 600, end: now + 1200 }
  });

  const outputTokens = 30 + replyText.length;
  const tokens = {
    total: inputTokens + outputTokens,
    input: inputTokens,
    output: outputTokens,
    reasoning: 10,
    cache: { read: 0, write: 0 }
  };

  parts.push({
    id: generateID('prt'), sessionID: sessionId, messageID, type: 'step-finish',
    reason: 'stop',
    snapshot: randomBytes(20).toString('hex'),
    tokens,
    cost: 0
  });

  if (lower.includes('permission') || lower.includes('权限')) {
    parts.push({
      id: generateID('prt'), sessionID: sessionId, messageID, type: 'patch',
      hash: randomBytes(20).toString('hex'),
      files: ['/example/file.ts']
    });
  }

  return { parts, tokens };
}

function handleRequest(req: IncomingMessage, res: ServerResponse): void {
  const url = new URL(req.url || '/', `http://localhost:${PORT}`);
  const path = url.pathname;
  const method = req.method || 'GET';

  res.setHeader('Content-Type', 'application/json');
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Last-Event-ID');

  if (method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  // Config / Version
  if (method === 'GET' && (path === '/config' || path === '/version')) {
    res.writeHead(200);
    res.end(JSON.stringify({ version: MOCK_VERSION, model: 'mock/mock-gpt' }));
    return;
  }

  // Health
  if (method === 'GET' && path === '/health') {
    res.writeHead(200);
    res.end(JSON.stringify({ status: 'ok', sessions: sessions.size }));
    return;
  }

  // Create session: POST /session
  if (method === 'POST' && path === '/session') {
    const session = createSessionObj();
    sessions.set(session.id, session);
    messages.set(session.id, []);
    console.log(`[MockOpencode] Created session: ${session.id} (${session.slug})`);
    res.writeHead(200);
    res.end(JSON.stringify(session));
    return;
  }

  // List sessions: GET /session
  if (method === 'GET' && path === '/session') {
    const list = Array.from(sessions.values());
    res.writeHead(200);
    res.end(JSON.stringify(list));
    return;
  }

  // Delete session: DELETE /session/:id
  const deleteMatch = path.match(/^\/session\/([^/]+)$/);
  if (method === 'DELETE' && deleteMatch) {
    const id = decodeURIComponent(deleteMatch[1]);
    sessions.delete(id);
    messages.delete(id);
    console.log(`[MockOpencode] Deleted session: ${id}`);
    res.writeHead(200);
    res.end(JSON.stringify({ status: 'ok' }));
    return;
  }

  // Get messages: GET /session/:id/message
  const historyMatch = path.match(/^\/session\/([^/]+)\/message$/);
  if (method === 'GET' && historyMatch) {
    const sessionId = decodeURIComponent(historyMatch[1]);
    if (!sessions.has(sessionId)) {
      res.writeHead(404);
      res.end(JSON.stringify({ error: 'Session not found' }));
      return;
    }
    const msgs = messages.get(sessionId) || [];
    res.writeHead(200);
    res.end(JSON.stringify(msgs));
    return;
  }

  // Send message: POST /session/:id/message (with optional subscribe=true)
  const messageMatch = path.match(/^\/session\/([^/]+)\/message$/);
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
      const parsed = JSON.parse(body || '{}');
      const userText = parsed.parts?.[0]?.text || '';

      // Save user message
      const userMsg: MockMessage = {
        info: {
          id: generateID('msg'),
          sessionID: sessionId,
          role: 'user',
          time: { created: Date.now() },
          agent: 'build'
        },
        parts: [{
          id: generateID('prt'),
          sessionID: sessionId,
          messageID: generateID('msg'),
          type: 'text',
          text: userText
        }]
      };
      const msgList = messages.get(sessionId) || [];
      msgList.push(userMsg);

      console.log(`[MockOpencode] Message in session ${sessionId}: ${userText}`);

      // Generate assistant response
      const { parts, tokens } = generateAssistantParts(sessionId, userText);
      const assistantMsgID = generateID('msg');
      const assistantMsg: MockMessage = {
        info: {
          id: assistantMsgID,
          sessionID: sessionId,
          role: 'assistant',
          time: { created: Date.now(), completed: Date.now() + 1500 },
          model: MODEL,
          agent: 'build',
          finish: 'stop',
          cost: 0,
          tokens: { ...tokens, total: tokens.total }
        },
        parts
      };
      msgList.push(assistantMsg);

      // Update session tokens
      session.tokens.input += tokens.input;
      session.tokens.output += tokens.output;
      session.time.updated = Date.now();

      const subscribe = url.searchParams.get('subscribe') === 'true';

      if (subscribe) {
        res.writeHead(200, { 'Content-Type': 'application/json', 'Transfer-Encoding': 'chunked' });
        const fullResponse = JSON.stringify(assistantMsg);
        const chunks = fullResponse.match(/.{1,512}/gs) || [fullResponse];
        let delay = 100;
        for (const chunk of chunks) {
          setTimeout(((c: string) => () => {
            if (!res.writableEnded) res.write(c);
          })(chunk), delay);
          delay += 80;
        }
        setTimeout(() => {
          if (!res.writableEnded) res.end();
        }, delay + 100);
      } else {
        res.writeHead(200);
        res.end(JSON.stringify(assistantMsg));
      }
    });
    return;
  }

  // Permissions
  const permMatch = path.match(/^\/permission(?:\/([^/]+))?$/);
  if (permMatch) {
    if (method === 'GET') {
      res.writeHead(200);
      res.end(JSON.stringify([]));
      return;
    }
    if (method === 'POST') {
      let body = '';
      req.on('data', chunk => body += chunk);
      req.on('end', () => {
        console.log(`[MockOpencode] Permission response: ${body}`);
        res.writeHead(200);
        res.end(JSON.stringify({ status: 'ok' }));
      });
      return;
    }
  }

  // Tools list
  if (method === 'GET' && path === '/tool') {
    res.writeHead(200);
    res.end(JSON.stringify([]));
    return;
  }

  // 404
  res.writeHead(404);
  res.end(JSON.stringify({ error: `Not found: ${method} ${path}` }));
}

const server = createServer(handleRequest);

const isMainModule = import.meta.url === `file://${process.argv[1]}`;

if (isMainModule) {
  server.listen(PORT, () => {
    console.log(`[MockOpencode] Server running on http://localhost:${PORT} (v${MOCK_VERSION})`);
    console.log('[MockOpencode] Aligned with real opencode serve API:');
    console.log('  POST   /session              - Create session');
    console.log('  GET    /session              - List sessions');
    console.log('  DELETE /session/:id           - Delete session');
    console.log('  GET    /session/:id/message   - Get message history');
    console.log('  POST   /session/:id/message   - Send message (?subscribe=true for stream)');
    console.log('  GET    /permission            - List permissions');
    console.log('  POST   /permission/:id        - Respond to permission');
    console.log('  GET    /config                - Server config/version');
  });

  process.on('SIGINT', () => {
    console.log('\n[MockOpencode] Shutting down...');
    server.close();
    process.exit(0);
  });
}

export { handleRequest, server, sessions, messages, MOCK_VERSION };
