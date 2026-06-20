export interface QRCodeData {
  mode: 'direct' | 'relay';
  name: string;
  host: string;
  port: number;
  publicKey: string;
  token: string;
  expiresAt?: number;
  relayUrl?: string;
  relayKey?: string;
}

export interface Connection {
  id: string;
  name: string;
  mode: 'direct' | 'relay';
  host: string;
  port: number;
  publicKey: string;
  token: string;
  relayUrl?: string;
  isOnline: boolean;
  lastConnected?: number;
}

export interface Session {
  id: string;
  name: string;
  createdAt: number;
  lastActivity: number;
}

export type MessageType =
  | 'user_message'
  | 'message_ack'
  | 'thinking'
  | 'tool_call'
  | 'permission_request'
  | 'permission_reply'
  | 'reply'
  | 'review_url'
  | 'session_list'
  | 'session_switch'
  | 'session_create'
  | 'session_delete'
  | 'token_info'
  | 'token_query'
  | 'history'
  | 'heartbeat'
  | 'error';

export interface MessageData {
  content?: string;
  name?: string;
  parameters?: string | object;
  result?: string;
  description?: string;
  requestId?: string;
  allowed?: boolean;
  reason?: string;
  url?: string;
  sessions?: Session[];
  sessionId?: string;
  messages?: object[];
  hasMore?: boolean;
  cursor?: string;
  total?: number;
  input?: number;
  output?: number;
  contextWindow?: number;
  limit?: number;
  id?: string;
  status?: string;
  code?: string;
  message?: string;
}

export interface Message {
  type: MessageType;
  id: string;
  seq?: number;
  stream?: string;
  data: MessageData;
  timestamp: number;
}

export interface EncryptedMessage {
  iv: string;
  ciphertext: string;
}

export interface HandshakeInit {
  type: 'handshake_init';
  publicKey: string;
  nonce: string;
  token: string;
  version: string;
}

export interface HandshakeAck {
  type: 'handshake_ack';
  publicKey: string;
  nonce: string;
  version: string;
  verify?: EncryptedMessage;
}

export interface HandshakeComplete {
  type: 'handshake_complete';
  verify: EncryptedMessage;
}
