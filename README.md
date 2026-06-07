# DCode

DCode is a HarmonyOS mobile app that connects to opencode (AI coding assistant) running on your desktop computer. It provides a mobile interface for interacting with opencode sessions, viewing thinking processes, tool calls, and managing permissions.

## Architecture

The system consists of three main components:

1. **Gateway** (Node.js) - Desktop service that bridges opencode with the mobile app via WebSocket
2. **Relay** (Node.js) - Cloud relay server for cross-network communication
3. **App** (HarmonyOS ArkTS) - Mobile client application

### Connection Modes

- **Direct Connection**: App ? Gateway (same network)
- **Cloud Relay**: App ? Relay ? Gateway (cross-network)

### Security

All communication is encrypted using:
- X25519 ECDH key exchange
- AES-256-GCM encryption
- QR code scanning for secure initial pairing (prevents MITM attacks)

## Features

### App Features

- **Connection Management**
  - QR code scanning for instant pairing
  - Manual connection setup
  - Save and manage multiple connections
  - Connection status indicators

- **Chat Interface**
  - Real-time message display
  - Thinking process visualization (collapsible)
  - Tool call results display
  - Permission request handling with approve/deny buttons
  - Markdown rendering with Mermaid diagram support

- **Session Management**
  - Create new sessions
  - Switch between sessions
  - View session list

- **Additional Features**
  - Token usage monitoring
  - Voice input support (HarmonyOS ASR)
  - Code review page (WebView)
  - Auto-reconnection with exponential backoff

### Gateway Features

- WebSocket server (direct mode) or client (relay mode)
- ECDH encryption handshake
- Session management
- Opencode HTTP/SSE integration
- QR code generation for pairing
- Message chunking for large payloads
- Automatic reconnection to relay server

### Relay Features

- Transparent message forwarding
- Token-based pairing
- Heartbeat monitoring
- Rate limiting (100 messages/minute)
- Automatic session cleanup

## Prerequisites

- Node.js 18+
- DevEco Studio (for app development)
- Docker and Docker Compose (optional, for containerized deployment)

## Quick Start

### 1. Start Development Environment

Using Docker Compose (recommended):

```bash
docker-compose up -d
```

This starts:
- Mock opencode server on port 3000
- Relay server on port 8766
- Gateway on port 8765

### 2. Manual Setup

#### Start Mock Opencode Server (for testing)

```bash
cd mock-opencode
npm install
npm run dev
```

The mock server will run on http://localhost:3000

#### Start Relay Server (for cloud relay mode)

```bash
cd relay
npm install
npm run dev
```

#### Start Gateway

```bash
cd gateway
npm install
npm run dev
```

The gateway will display a QR code in the terminal for app pairing.

### 3. Build and Run the App

1. Open `app/` in DevEco Studio
2. Configure an emulator or connect a HarmonyOS device
3. Run the app

### 4. Connect

1. Tap "扫一扫" (Scan) on the app
2. Scan the QR code displayed in the gateway terminal
3. Choose "连接并保存" (Connect and Save) or "仅连接一次" (Connect Once)

## Configuration

### Gateway Configuration

Create `gateway/gateway.config.json` (copy from `gateway.config.example.json`):

```json
{
  "mode": "direct",
  "host": "0.0.0.0",
  "port": 8765,
  "relayUrl": "ws://localhost:8766",
  "opencodeUrl": "http://localhost:3000",
  "computerName": "MyPC",
  "version": "0.1.0"
}
```

Environment variables (override config file):
- `DCODE_MODE` - Connection mode (direct/relay)
- `DCODE_HOST` - Bind host
- `DCODE_PORT` - Bind port
- `DCODE_RELAY_URL` - Relay server URL
- `DCODE_OPENCODE_URL` - Opencode server URL
- `DCODE_COMPUTER_NAME` - Display name

Command line arguments:
- `--mode=relay`
- `--port=8765`
- `--relay-url=ws://...`
- `--opencode-url=http://...`

## Testing

### Gateway Tests

```bash
cd gateway
npm test
```

### Relay Tests

```bash
cd relay
npm test
```

### Integration Testing

1. Start all services (mock-opencode, relay, gateway)
2. Run the app on emulator/device
3. Test connection flow:
   - QR scan pairing
   - Manual connection
   - Direct mode
   - Relay mode
4. Test chat features:
   - Send messages
   - View thinking process
   - Handle tool calls
   - Respond to permission requests
5. Test session management:
   - Create sessions
   - Switch sessions
   - Delete sessions

## Development

### Project Structure

```
dcode/
├── app/                    # HarmonyOS mobile app (ArkTS)
│   └── entry/
│       └── src/
│           └── main/
│               └── ets/
│                   ├── components/    # UI components
│                   ├── pages/         # App pages
│                   ├── services/      # Business logic
│                   └── models/        # Data models
├── gateway/                # Node.js gateway service
│   └── src/
│       ├── crypto/         # Encryption module
│       ├── opencode/       # Opencode client
│       ├── session/        # Session management
│       └── ws/             # WebSocket handlers
├── relay/                  # Node.js relay server
│   └── src/
├── mock-opencode/          # Mock opencode for testing
│   └── src/
└── docker-compose.yml      # Container orchestration
```

### Message Protocol

All messages use JSON text frames with structure:

```typescript
{
  type: MessageType,
  id: string,
  data: any,
  timestamp: number
}
```

Message types:
- `user_message` - User input
- `thinking` - AI thinking process
- `tool_call` - Tool invocation
- `permission_request` - Permission prompt
- `permission_reply` - User's permission decision
- `reply` - AI response
- `review_url` - Code review URL
- `session_list` - Session list update
- `session_switch` - Session switch notification
- `session_create` - Create new session
- `token_info` - Token usage info
- `error` - Error message
- `heartbeat` - Connection keepalive

### QR Code Format

```json
{
  "mode": "direct" | "relay",
  "name": "Computer name",
  "host": "192.168.x.x",
  "port": 8765,
  "publicKey": "base64-encoded-x25519-public-key",
  "token": "uuid",
  "relayUrl": "wss://..." // relay mode only
}
```

## Troubleshooting

### App cannot connect to gateway

- Ensure gateway is running and accessible
- Check firewall settings
- Verify same network (direct mode) or relay server availability
- Check gateway logs for errors

### Connection drops frequently

- Check network stability
- Verify heartbeat interval settings
- Review relay server logs (if using relay mode)

### QR code scanning fails

- Ensure camera permission is granted
- Check lighting conditions
- Try manual connection as fallback

### Tests timeout

- Check if ports 8765 and 8766 are available
- Ensure no other services are using the ports
- Run tests individually to isolate issues

## License

MIT

## Contributing

1. Follow the coding standards in AGENTS.md
2. Write tests for new features
3. Update documentation as needed
4. Use conventional commits

## Future Enhancements

- Push notifications for permission requests
- Offline mode with message queue
- Multi-language support
- Dark mode
- Remote emulator support
- App distribution (push to device)
