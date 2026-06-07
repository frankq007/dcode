export type MessageType = 
  | 'user_message'
  | 'thinking'
  | 'tool_call'
  | 'permission_request'
  | 'permission_reply'
  | 'reply'
  | 'review_url'
  | 'session_list'
  | 'session_switch'
  | 'session_create'
  | 'token_info'
  | 'error'
  | 'heartbeat';

export interface Message {
  type: MessageType;
  id: string;
  data: any;
  timestamp: number;
}

export interface HandshakeMessage {
  type: 'handshake_init' | 'handshake_ack' | 'handshake_complete';
  publicKey: string;
  nonce: string;
  version: string;
}

export interface QRCodeData {
  mode: 'direct' | 'relay';
  name: string;
  host: string;
  port: number;
  publicKey: string;
  token: string;
  relayUrl?: string;
}
