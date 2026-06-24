export const DEFAULT_MAX_MESSAGE_SIZE = 1024 * 1024;

export interface Chunk {
  type: 'chunk';
  messageId: string;
  index: number;
  total: number;
  data: string;
}

export function chunkMessage(plaintext: string, maxMessageSize: number): string[] {
  const encoder = new TextEncoder();
  const encoded = encoder.encode(plaintext);

  if (encoded.length <= maxMessageSize) {
    return [plaintext];
  }

  const chunks: string[] = [];
  const decoder = new TextDecoder();
  let offset = 0;

  while (offset < encoded.length) {
    const end = Math.min(offset + maxMessageSize, encoded.length);
    const slice = encoded.subarray(offset, end);
    const isLast = end >= encoded.length;
    chunks.push(decoder.decode(slice, { stream: !isLast }));
    offset = end;
  }

  return chunks;
}

export function reassembleMessage(chunks: string[]): string {
  return chunks.join('');
}

export function buildChunkEnvelope(messageId: string, index: number, total: number, data: string): Chunk {
  return { type: 'chunk', messageId, index, total, data };
}
