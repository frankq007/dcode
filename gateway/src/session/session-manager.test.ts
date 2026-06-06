import { describe, it, expect, beforeEach } from 'vitest';
import { SessionManager } from './session-manager';

describe('SessionManager', () => {
  let manager: SessionManager;

  beforeEach(() => {
    manager = new SessionManager();
  });

  it('should create a new session', () => {
    const session = manager.create('Test Session');
    
    expect(session).toBeDefined();
    expect(session.id).toBeDefined();
    expect(session.name).toBe('Test Session');
    expect(session.createdAt).toBeDefined();
    expect(session.lastActivity).toBeDefined();
  });

  it('should create session with default name if not provided', () => {
    const session = manager.create();
    
    expect(session.name).toBe('Session 1');
  });

  it('should list all sessions', () => {
    manager.create('Session 1');
    manager.create('Session 2');
    manager.create('Session 3');
    
    const sessions = manager.list();
    expect(sessions.length).toBe(3);
  });

  it('should get active session', () => {
    const session1 = manager.create('Session 1');
    const session2 = manager.create('Session 2');
    
    const active = manager.getActive();
    expect(active?.id).toBe(session2.id);
  });

  it('should switch between sessions', () => {
    const session1 = manager.create('Session 1');
    const session2 = manager.create('Session 2');
    
    const switched = manager.switch(session1.id);
    expect(switched?.id).toBe(session1.id);
    
    const active = manager.getActive();
    expect(active?.id).toBe(session1.id);
  });

  it('should delete a session', () => {
    const session1 = manager.create('Session 1');
    const session2 = manager.create('Session 2');
    
    const deleted = manager.delete(session1.id);
    expect(deleted).toBe(true);
    
    const sessions = manager.list();
    expect(sessions.length).toBe(1);
    expect(sessions[0].id).toBe(session2.id);
  });

  it('should update active session when current active is deleted', () => {
    const session1 = manager.create('Session 1');
    const session2 = manager.create('Session 2');
    
    manager.delete(session2.id);
    
    const active = manager.getActive();
    expect(active?.id).toBe(session1.id);
  });

  it('should touch session to update last activity', () => {
    const session = manager.create('Test Session');
    const originalActivity = session.lastActivity;
    
    // Wait a bit to ensure timestamp changes
    setTimeout(() => {
      manager.touch(session.id);
      const updated = manager.get(session.id);
      expect(updated?.lastActivity).toBeGreaterThan(originalActivity);
    }, 10);
  });

  it('should return null when switching to non-existent session', () => {
    const result = manager.switch('non-existent-id');
    expect(result).toBeNull();
  });

  it('should return false when deleting non-existent session', () => {
    const result = manager.delete('non-existent-id');
    expect(result).toBe(false);
  });
});
