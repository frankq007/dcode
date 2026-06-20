export type MessageType = 
  | 'user_message'
  | 'message_ack'
  | 'cancel'
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
  | 'chunk'
  | 'chunk_resend'
  | 'sync'
  | 'error';

export interface Message {
  type: MessageType;
  id: string;
  seq?: number;
  stream?: string;
  data: any;
  timestamp: number;
}

export interface HandshakeMessage {
  type: 'handshake_init' | 'handshake_ack' | 'handshake_complete';
  publicKey: string;
  nonce: string;
  token?: string;
  version: string;
  verify?: { iv: string; ciphertext: string };
}

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
