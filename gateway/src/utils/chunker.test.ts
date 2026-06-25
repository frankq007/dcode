import { describe, it, expect } from 'vitest';
import {
  chunkMessage,
  reassembleChunks,
  missingSeqs,
  isValidChunk,
  isChunkStatus,
  DEFAULT_MAX_MESSAGE_SIZE,
  CHUNK_MAX_RESENDS,
  type Chunk
} from './chunker';

describe('Chunker', () => {
  describe('chunkMessage', () => {
    it('should return empty array for messages smaller than maxMessageSize', () => {
      const chunks = chunkMessage('Hello, World!', 1024);
      expect(chunks).toHaveLength(0);
    });

    it('should return empty array for messages exactly equal to maxMessageSize', () => {
      const chunks = chunkMessage('A'.repeat(1024), 1024);
      expect(chunks).toHaveLength(0);
    });

    it('should chunk messages larger than maxMessageSize', () => {
      const chunks = chunkMessage('A'.repeat(2500), 1024);
      expect(chunks.length).toBe(3);
    });

    it('should handle very large messages', () => {
      const chunks = chunkMessage('X'.repeat(5 * 1024 * 1024), DEFAULT_MAX_MESSAGE_SIZE);
      expect(chunks.length).toBe(5);
    });

    it('should assign start/data/end status correctly', () => {
      const chunks = chunkMessage('A'.repeat(5000), 1024);
      expect(chunks.length).toBe(5);
      expect(chunks[0].status).toBe('start');
      expect(chunks[1].status).toBe('data');
      expect(chunks[2].status).toBe('data');
      expect(chunks[3].status).toBe('data');
      expect(chunks[4].status).toBe('end');
    });

    it('should assign start/end status for a two-chunk message', () => {
      const chunks = chunkMessage('A'.repeat(2000), 1024);
      expect(chunks).toHaveLength(2);
      expect(chunks[0].status).toBe('start');
      expect(chunks[1].status).toBe('end');
    });

    it('should share a single chunkId across all chunks', () => {
      const chunks = chunkMessage('A'.repeat(5000), 1024);
      const ids = new Set(chunks.map((c) => c.chunkId));
      expect(ids.size).toBe(1);
      expect(chunks[0].chunkId.length).toBeGreaterThan(0);
    });

    it('should set total and seq correctly', () => {
      const chunks = chunkMessage('A'.repeat(5000), 1024);
      expect(chunks.length).toBe(5);
      chunks.forEach((c, i) => {
        expect(c.seq).toBe(i);
        expect(c.total).toBe(5);
      });
    });

    it('should base64-encode payloads', () => {
      const plaintext = 'Hello, World!';
      const chunks = chunkMessage(plaintext + 'A'.repeat(2000), 1024);
      expect(chunks.length).toBeGreaterThan(1);
      const firstPayload = Buffer.from(chunks[0].payload, 'base64').toString('utf-8');
      expect(firstPayload.startsWith(plaintext)).toBe(true);
    });

    it('should preserve message content through chunk-reassemble cycle', () => {
      const message = 'The quick brown fox jumps over the lazy dog. '.repeat(100);
      const chunks = chunkMessage(message, 100);
      expect(chunks.length).toBeGreaterThan(1);
      const reassembled = reassembleChunks(chunks);
      expect(reassembled).toBe(message);
    });

    it('should handle UTF-8 multibyte characters', () => {
      const message = '你好世界'.repeat(500);
      const chunks = chunkMessage(message, 1024);
      expect(chunks.length).toBeGreaterThan(1);
      const reassembled = reassembleChunks(chunks);
      expect(reassembled).toBe(message);
    });
  });

  describe('reassembleChunks', () => {
    it('should reassemble a single chunk', () => {
      const payload = Buffer.from('Complete message', 'utf-8').toString('base64');
      const chunks: Chunk[] = [
        { chunkId: 'c1', seq: 0, total: 1, payload, status: 'start' }
      ];
      expect(reassembleChunks(chunks)).toBe('Complete message');
    });

    it('should reassemble multiple chunks in order', () => {
      const chunks: Chunk[] = [
        { chunkId: 'c1', seq: 0, total: 3, payload: Buffer.from('Hello, ').toString('base64'), status: 'start' },
        { chunkId: 'c1', seq: 1, total: 3, payload: Buffer.from('World').toString('base64'), status: 'data' },
        { chunkId: 'c1', seq: 2, total: 3, payload: Buffer.from('!').toString('base64'), status: 'end' }
      ];
      expect(reassembleChunks(chunks)).toBe('Hello, World!');
    });

    it('should tolerate out-of-order arrival', () => {
      const original = '0123456789'.repeat(500);
      const chunks = chunkMessage(original, 1024);
      const shuffled = [...chunks].reverse();
      expect(reassembleChunks(shuffled)).toBe(original);
    });

    it('should tolerate random-order arrival', () => {
      const original = 'ABCDEFGH'.repeat(1000);
      const chunks = chunkMessage(original, 512);
      const shuffled = [...chunks].sort(() => (Math.random() > 0.5 ? 1 : -1));
      expect(reassembleChunks(shuffled)).toBe(original);
    });

    it('should handle empty payload fragments', () => {
      const chunks: Chunk[] = [
        { chunkId: 'c1', seq: 0, total: 2, payload: Buffer.from('').toString('base64'), status: 'start' },
        { chunkId: 'c1', seq: 1, total: 2, payload: Buffer.from('only').toString('base64'), status: 'end' }
      ];
      expect(reassembleChunks(chunks)).toBe('only');
    });
  });

  describe('missingSeqs', () => {
    it('should return all seqs when nothing received', () => {
      expect(missingSeqs(5, new Set())).toEqual([0, 1, 2, 3, 4]);
    });

    it('should return empty array when all received', () => {
      expect(missingSeqs(3, new Set([0, 1, 2]))).toEqual([]);
    });

    it('should return missing seqs in order', () => {
      expect(missingSeqs(5, new Set([0, 3]))).toEqual([1, 2, 4]);
    });

    it('should handle total of 1', () => {
      expect(missingSeqs(1, new Set())).toEqual([0]);
      expect(missingSeqs(1, new Set([0]))).toEqual([]);
    });
  });

  describe('roundtrip', () => {
    it('should preserve message through chunk-reassemble cycle', () => {
      const original = 'This is a test message that will be chunked and reassembled.'.repeat(50);
      const chunks = chunkMessage(original, 512);
      expect(chunks.length).toBeGreaterThan(1);
      const reassembled = reassembleChunks(chunks);
      expect(reassembled).toBe(original);
    });

    it('should handle JSON payloads', () => {
      const payload = {
        type: 'message',
        content: 'A'.repeat(2000),
        metadata: { timestamp: Date.now(), user: 'test' }
      };
      const original = JSON.stringify(payload);
      const chunks = chunkMessage(original, 512);
      const reassembled = reassembleChunks(chunks);
      const parsed = JSON.parse(reassembled);
      expect(parsed).toEqual(payload);
    });
  });

  describe('isChunkStatus', () => {
    it('should accept valid statuses', () => {
      expect(isChunkStatus('start')).toBe(true);
      expect(isChunkStatus('data')).toBe(true);
      expect(isChunkStatus('end')).toBe(true);
    });

    it('should reject invalid statuses', () => {
      expect(isChunkStatus('begin')).toBe(false);
      expect(isChunkStatus('')).toBe(false);
      expect(isChunkStatus(null)).toBe(false);
      expect(isChunkStatus(42)).toBe(false);
    });
  });

  describe('isValidChunk', () => {
    it('should accept a valid chunk object', () => {
      const chunk: Chunk = {
        chunkId: 'abc',
        seq: 0,
        total: 2,
        payload: 'aGVsbG8=',
        status: 'start'
      };
      expect(isValidChunk(chunk)).toBe(true);
    });

    it('should reject objects missing required fields', () => {
      expect(isValidChunk({})).toBe(false);
      expect(isValidChunk({ chunkId: 'x', seq: 0, total: 1 })).toBe(false);
      expect(isValidChunk({ chunkId: 'x', seq: 0, total: 1, payload: 'a', status: 'start', extra: 1 })).toBe(true);
    });

    it('should reject wrong types', () => {
      expect(isValidChunk(null)).toBe(false);
      expect(isValidChunk('chunk')).toBe(false);
      expect(isValidChunk({ chunkId: 1, seq: 0, total: 1, payload: 'a', status: 'start' })).toBe(false);
      expect(isValidChunk({ chunkId: 'x', seq: '0', total: 1, payload: 'a', status: 'start' })).toBe(false);
      expect(isValidChunk({ chunkId: 'x', seq: 0, total: 1, payload: 'a', status: 'middle' })).toBe(false);
    });
  });

  describe('chunk_resend simulation', () => {
    it('should compute missing seqs after partial arrival', () => {
      const original = 'A'.repeat(5000);
      const chunks = chunkMessage(original, 1024);
      expect(chunks).toHaveLength(5);

      const received = new Set<number>([0, 2, 4]);
      const missing = missingSeqs(chunks[0].total, received);
      expect(missing).toEqual([1, 3]);

      const partial = chunks.filter((c) => received.has(c.seq));
      const resent = chunks.filter((c) => missing.includes(c.seq));
      const all = [...partial, ...resent];
      expect(reassembleChunks(all)).toBe(original);
    });

    it('should support multiple resend rounds until complete', () => {
      const original = 'B'.repeat(4000);
      const chunks = chunkMessage(original, 1024);
      const total = chunks[0].total;

      let received = new Set<number>([0]);
      let round = 0;
      while (received.size < total && round < CHUNK_MAX_RESENDS) {
        const missing = missingSeqs(total, received);
        for (const seq of missing) {
          received.add(seq);
        }
        round++;
      }
      expect(received.size).toBe(total);
      expect(round).toBeLessThanOrEqual(CHUNK_MAX_RESENDS);
    });
  });
});
