export interface QRCodeData {
  mode: 'direct' | 'relay';
  name: string;
  host: string;
  port: number;
  publicKey: string;
  token: string;
  relayUrl?: string;
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
