export type MessageType = 
  | 'user_message'
  | 'thinking'
  | 'tool_call'
  | 'permission_request'
  | 'permission_reply'
  | 'reply'
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
  publicKey: string;  // Base64
  nonce: string;      // Base64
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
