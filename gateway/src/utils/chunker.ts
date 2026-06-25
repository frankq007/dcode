import { randomUUID } from 'crypto';

export const DEFAULT_MAX_MESSAGE_SIZE = 1024 * 1024;

export type ChunkStatus = 'start' | 'data' | 'end';

export interface Chunk {
  chunkId: string;
  seq: number;
  total: number;
  payload: string;
  status: ChunkStatus;
}

export const CHUNK_RESEND_TIMEOUT = 5000;
export const CHUNK_REASSEMBLY_TIMEOUT = 30000;
export const CHUNK_MAX_RESENDS = 3;
export const SENT_CHUNKS_TTL = 60000;

export function chunkMessage(plaintext: string, maxMessageSize: number): Chunk[] {
  const encoded = Buffer.from(plaintext, 'utf-8');

  if (encoded.length <= maxMessageSize) {
    return [];
  }

  const chunkId = randomUUID();
  const fragments: string[] = [];
  let offset = 0;

  while (offset < encoded.length) {
    const end = Math.min(offset + maxMessageSize, encoded.length);
    fragments.push(encoded.subarray(offset, end).toString('base64'));
    offset = end;
  }

  const total = fragments.length;
  return fragments.map((payload, seq): Chunk => {
    let status: ChunkStatus;
    if (seq === 0) {
      status = 'start';
    } else if (seq === total - 1) {
      status = 'end';
    } else {
      status = 'data';
    }
    return { chunkId, seq, total, payload, status };
  });
}

export function reassembleChunks(chunks: Chunk[]): string {
  const sorted = [...chunks].sort((a, b) => a.seq - b.seq);
  const buffers: Buffer[] = sorted.map((c) => Buffer.from(c.payload, 'base64'));
  return Buffer.concat(buffers).toString('utf-8');
}

export function missingSeqs(total: number, received: Set<number>): number[] {
  const missing: number[] = [];
  for (let i = 0; i < total; i++) {
    if (!received.has(i)) missing.push(i);
  }
  return missing;
}

export function isChunkStatus(value: unknown): value is ChunkStatus {
  return value === 'start' || value === 'data' || value === 'end';
}

export function isValidChunk(data: unknown): data is Chunk {
  if (!data || typeof data !== 'object') return false;
  const c = data as Record<string, unknown>;
  return (
    typeof c.chunkId === 'string' &&
    typeof c.seq === 'number' &&
    typeof c.total === 'number' &&
    typeof c.payload === 'string' &&
    isChunkStatus(c.status)
  );
}
