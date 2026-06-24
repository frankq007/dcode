import { describe, it, expect } from 'vitest';
import { chunkMessage, reassembleMessage, buildChunkEnvelope, DEFAULT_MAX_MESSAGE_SIZE } from './chunker';

describe('Chunker', () => {
  describe('chunkMessage', () => {
    it('should not chunk messages smaller than maxMessageSize', () => {
      const message = 'Hello, World!';
      const chunks = chunkMessage(message, 1024);
      expect(chunks).toHaveLength(1);
      expect(chunks[0]).toBe(message);
    });

    it('should not chunk messages exactly equal to maxMessageSize', () => {
      const message = 'A'.repeat(1024);
      const chunks = chunkMessage(message, 1024);
      expect(chunks).toHaveLength(1);
      expect(chunks[0]).toBe(message);
    });

    it('should chunk messages larger than maxMessageSize', () => {
      const message = 'A'.repeat(2500);
      const chunks = chunkMessage(message, 1024);
      expect(chunks.length).toBeGreaterThan(1);
      expect(chunks.length).toBe(3); // 2500 bytes = 3 chunks (1024 + 1024 + 452)
    });

    it('should handle very large messages', () => {
      const message = 'X'.repeat(5 * 1024 * 1024); // 5MB
      const chunks = chunkMessage(message, DEFAULT_MAX_MESSAGE_SIZE); // 1MB default
      expect(chunks.length).toBe(5);
    });

    it('should preserve message content through chunking', () => {
      const message = 'The quick brown fox jumps over the lazy dog. '.repeat(100);
      const chunks = chunkMessage(message, 100);
      const reassembled = reassembleMessage(chunks);
      expect(reassembled).toBe(message);
    });

    it('should handle UTF-8 multibyte characters', () => {
      const message = '你好世界'.repeat(500); // Each char is 3 bytes in UTF-8
      const chunks = chunkMessage(message, 1024);
      expect(chunks.length).toBeGreaterThan(1);
      const reassembled = reassembleMessage(chunks);
      expect(reassembled).toBe(message);
    });

    it('should handle empty message', () => {
      const message = '';
      const chunks = chunkMessage(message, 1024);
      expect(chunks).toHaveLength(1);
      expect(chunks[0]).toBe('');
    });
  });

  describe('reassembleMessage', () => {
    it('should reassemble chunks correctly', () => {
      const chunks = ['Hello, ', 'World', '!'];
      const message = reassembleMessage(chunks);
      expect(message).toBe('Hello, World!');
    });

    it('should handle single chunk', () => {
      const chunks = ['Complete message'];
      const message = reassembleMessage(chunks);
      expect(message).toBe('Complete message');
    });

    it('should handle empty chunks array', () => {
      const chunks: string[] = [];
      const message = reassembleMessage(chunks);
      expect(message).toBe('');
    });
  });

  describe('buildChunkEnvelope', () => {
    it('should build correct chunk envelope', () => {
      const envelope = buildChunkEnvelope('msg-123', 0, 3, 'chunk-data');
      expect(envelope).toEqual({
        type: 'chunk',
        messageId: 'msg-123',
        index: 0,
        total: 3,
        data: 'chunk-data'
      });
    });

    it('should handle different indices', () => {
      const envelope0 = buildChunkEnvelope('msg-456', 0, 5, 'first');
      const envelope2 = buildChunkEnvelope('msg-456', 2, 5, 'middle');
      const envelope4 = buildChunkEnvelope('msg-456', 4, 5, 'last');
      
      expect(envelope0.index).toBe(0);
      expect(envelope2.index).toBe(2);
      expect(envelope4.index).toBe(4);
      
      expect(envelope0.total).toBe(5);
      expect(envelope2.total).toBe(5);
      expect(envelope4.total).toBe(5);
    });
  });

  describe('roundtrip', () => {
    it('should preserve message through chunk-reassemble cycle', () => {
      const original = 'This is a test message that will be chunked and reassembled.'.repeat(50);
      const maxMessageSize = 512;
      
      const chunks = chunkMessage(original, maxMessageSize);
      expect(chunks.length).toBeGreaterThan(1);
      
      // Build envelopes
      const messageId = 'test-msg-001';
      const envelopes = chunks.map((chunk, index) => 
        buildChunkEnvelope(messageId, index, chunks.length, chunk)
      );
      
      // Extract data from envelopes (simulating receiver)
      const extractedChunks = envelopes.map(env => env.data);
      
      // Reassemble
      const reassembled = reassembleMessage(extractedChunks);
      expect(reassembled).toBe(original);
    });

    it('should handle JSON payloads', () => {
      const payload = {
        type: 'message',
        content: 'A'.repeat(2000),
        metadata: { timestamp: Date.now(), user: 'test' }
      };
      const original = JSON.stringify(payload);
      const maxMessageSize = 512;
      
      const chunks = chunkMessage(original, maxMessageSize);
      const reassembled = reassembleMessage(chunks);
      const parsed = JSON.parse(reassembled);
      
      expect(parsed).toEqual(payload);
    });
  });
});
