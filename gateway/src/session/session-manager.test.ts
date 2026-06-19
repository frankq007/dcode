import { describe, it, expect, beforeEach } from 'vitest';
import { SessionManager } from './session-manager';

describe('SessionManager', () => {
  let manager: SessionManager;

  beforeEach(() => {
    manager = new SessionManager();
  });

  it('should create a new session with given opencodeId', () => {
    const session = manager.create('oc-id-1', 'Test Session');

    expect(session).toBeDefined();
    expect(session.id).toBe('oc-id-1');
    expect(session.name).toBe('Test Session');
    expect(session.createdAt).toBeDefined();
    expect(session.lastActivity).toBeDefined();
    expect(session.lastActiveSeq).toBe(0);
  });

  it('should create session with default name if not provided', () => {
    const session = manager.create('oc-id-1');

    expect(session.name).toBe('Session 1');
  });

  it('should list all sessions', () => {
    manager.create('oc-id-1', 'Session 1');
    manager.create('oc-id-2', 'Session 2');
    manager.create('oc-id-3', 'Session 3');

    const sessions = manager.list();
    expect(sessions.length).toBe(3);
  });

  it('should get active session', () => {
    manager.create('oc-id-1', 'Session 1');
    manager.create('oc-id-2', 'Session 2');

    const active = manager.getActive();
    expect(active?.id).toBe('oc-id-2');
  });

  it('should switch between sessions', () => {
    manager.create('oc-id-1', 'Session 1');
    manager.create('oc-id-2', 'Session 2');

    const switched = manager.switch('oc-id-1');
    expect(switched?.id).toBe('oc-id-1');

    const active = manager.getActive();
    expect(active?.id).toBe('oc-id-1');
  });

  it('should delete a session', () => {
    manager.create('oc-id-1', 'Session 1');
    manager.create('oc-id-2', 'Session 2');

    const deleted = manager.delete('oc-id-1');
    expect(deleted).toBe(true);

    const sessions = manager.list();
    expect(sessions.length).toBe(1);
    expect(sessions[0].id).toBe('oc-id-2');
  });

  it('should update active session when current active is deleted', () => {
    manager.create('oc-id-1', 'Session 1');
    manager.create('oc-id-2', 'Session 2');

    manager.delete('oc-id-2');

    const active = manager.getActive();
    expect(active?.id).toBe('oc-id-1');
  });

  it('should touch session to update last activity', () => {
    const session = manager.create('oc-id-1', 'Test Session');
    const originalActivity = session.lastActivity;

    setTimeout(() => {
      manager.touch('oc-id-1');
      const updated = manager.get('oc-id-1');
      expect(updated?.lastActivity).toBeGreaterThan(originalActivity);
    }, 10);
  });

  it('should update lastActiveSeq', () => {
    manager.create('oc-id-1', 'Test Session');

    manager.updateSeq('oc-id-1', 5);
    expect(manager.get('oc-id-1')?.lastActiveSeq).toBe(5);

    manager.updateSeq('oc-id-1', 3);
    expect(manager.get('oc-id-1')?.lastActiveSeq).toBe(5);
  });

  it('should clear all sessions', () => {
    manager.create('oc-id-1', 'Session 1');
    manager.create('oc-id-2', 'Session 2');

    manager.clear();

    expect(manager.list().length).toBe(0);
    expect(manager.getActive()).toBeNull();
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
