# Repository Guidelines

This guide helps contributors understand the dcode project structure, development workflow, and coding standards.

## Project Structure & Module Organization

The project consists of three main components:

- **app/** - HarmonyOS mobile app built with ArkTS native language, targeting API 6.1+
  - Connection list page, main chat interface, QR scanner, and session management
  - Uses luvi/lv-markdown-in for Markdown rendering, WebView fallback for Mermaid diagrams
  
- **gateway/** - Node.js/TypeScript gateway service (runs on desktop)
  - Bridges opencode with the mobile app via WebSocket
  - Supports direct connection and cloud relay modes
  - Handles ECDH encryption (X25519 + AES-256-GCM)
  
- **relay/** - Lightweight Node.js/TypeScript relay server
  - Transparent message forwarding between gateway and app
  - Token-based pairing, heartbeat monitoring

## Build, Test, and Development Commands

**Prerequisites**: Node.js 18+, DevEco Studio (for app development)

`ash
# Start local development environment (Gateway + Relay + mock opencode)
docker-compose up -d

# Gateway
cd gateway
npm install
npm run dev          # Start with hot reload
npm test             # Run unit tests

# Relay
cd relay
npm install
npm run dev          # Start relay server
npm test             # Run unit tests

# App (via DevEco Studio)
# Open app/ in DevEco Studio, run on emulator or device
`

## Coding Style & Naming Conventions

**TypeScript (gateway/relay)**:
- ESLint + Prettier for formatting
- 2-space indentation, single quotes
- camelCase for variables/functions, PascalCase for types/classes
- Use async/await over callbacks

**ArkTS (app)**:
- Follow HarmonyOS ArkTS native coding standards (API 6.1+)
- Component names in PascalCase
- Structured logging with JSON format (timestamp, level, module, message)

## Testing Guidelines

Test cases follow the TC-{C|M|G}-xx naming convention from the design document:

- **TC-C**: Connection tests (QR scanning, pairing, encryption handshake)
- **TC-M**: Main chat tests (message rendering, voice input, session management)
- **TC-G**: Gateway/Relay tests (multi-session, reconnection, encryption)

Testing strategy:
- **Unit tests**: Core modules (encryption, message parsing, WebSocket handlers)
- **Integration tests**: App-Gateway-Relay communication flows
- **E2E tests**: Complete user workflows (scan QR → chat → permission handling)

## Commit & Pull Request Guidelines

**Commit messages**: Use Conventional Commits format
- eat: new features
- ix: bug fixes
- docs: documentation changes
- efactor: code refactoring
- 	est: adding tests

**Pull requests**:
- Include test coverage for new functionality
- Update documentation if behavior changes
- Reference related issues

## Architecture Overview

**Three roles**:
- **App** (mobile client): User interface, QR scanning, voice/text input
- **Gateway** (desktop service): Protocol bridge, encryption, opencode integration
- **Relay** (cloud server): Message forwarding for non-direct connections

**Two connection modes**:
- **Direct**: App ↔ Gateway (same network)
- **Cloud relay**: App ↔ Relay ↔ Gateway (cross-network)

**Key protocols**:
- QR code JSON: Contains connection info (mode, host, port, publicKey, token, relayUrl)
- ECDH handshake: Three-step process with nonce exchange
- WebSocket messages: JSON text frames with {type, data} structure
- HTTP/SSE: Gateway communicates with opencode serve

**Security**: End-to-end encryption using X25519 ECDH + AES-256-GCM. Trusts QR scanning physical channel for MITM protection.

For detailed design decisions and protocol specifications, see dcode.md (补充设计决策 section).