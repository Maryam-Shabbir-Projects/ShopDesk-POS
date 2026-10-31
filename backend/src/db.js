import { DatabaseSync } from 'node:sqlite';
import { mkdirSync } from 'node:fs';
import { dirname } from 'node:path';

const SCHEMA = `
CREATE TABLE IF NOT EXISTS users (
  id          TEXT PRIMARY KEY,
  email       TEXT NOT NULL UNIQUE,
  pass_hash   TEXT NOT NULL,
  role        TEXT NOT NULL DEFAULT 'owner',
  verified    INTEGER NOT NULL DEFAULT 0,
  created_at  INTEGER NOT NULL,
  signup_at   INTEGER NOT NULL
);

-- At most one live code per (email, purpose). Only a keyed hash is stored.
CREATE TABLE IF NOT EXISTS codes (
  email       TEXT NOT NULL,
  purpose     TEXT NOT NULL,            -- 'signup' | 'reset'
  code_hash   TEXT NOT NULL,
  expires_at  INTEGER NOT NULL,
  attempts    INTEGER NOT NULL DEFAULT 0,
  sent_at     INTEGER NOT NULL,
  PRIMARY KEY (email, purpose)
);

-- Proof that the reset code was entered. Single use, short life.
CREATE TABLE IF NOT EXISTS reset_tokens (
  token_hash  TEXT PRIMARY KEY,
  user_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  expires_at  INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS sessions (
  id          TEXT PRIMARY KEY,
  user_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash  TEXT NOT NULL UNIQUE,
  expires_at  INTEGER NOT NULL,
  revoked     INTEGER NOT NULL DEFAULT 0,
  created_at  INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS sessions_user ON sessions(user_id);

-- Generic counter used for "too many sends / too many wrong passwords".
CREATE TABLE IF NOT EXISTS throttle (
  key         TEXT PRIMARY KEY,
  count       INTEGER NOT NULL,
  reset_at    INTEGER NOT NULL
);
`;

export function openDb(path) {
  if (path !== ':memory:') mkdirSync(dirname(path), { recursive: true });
  const db = new DatabaseSync(path);
  db.exec('PRAGMA journal_mode = WAL;');
  db.exec('PRAGMA foreign_keys = ON;');
  db.exec(SCHEMA);
  return db;
}

/**
 * Counts one hit for `key`. Returns true while the count is within `limit`
 * for the current window, false once the limit is exceeded.
 */
export function hit(db, key, limit, windowMs, now = Date.now()) {
  const row = db.prepare('SELECT count, reset_at FROM throttle WHERE key = ?').get(key);
  if (!row || row.reset_at <= now) {
    db.prepare('INSERT OR REPLACE INTO throttle (key, count, reset_at) VALUES (?, 1, ?)').run(key, now + windowMs);
    return true;
  }
  db.prepare('UPDATE throttle SET count = count + 1 WHERE key = ?').run(key);
  return row.count + 1 <= limit;
}

/** True when `key` has already used up `limit` hits in the current window. */
export function isBlocked(db, key, limit, now = Date.now()) {
  const row = db.prepare('SELECT count, reset_at FROM throttle WHERE key = ?').get(key);
  return !!row && row.reset_at > now && row.count >= limit;
}

export function clearKey(db, key) {
  db.prepare('DELETE FROM throttle WHERE key = ?').run(key);
}

export function purgeExpired(db, now = Date.now()) {
  db.prepare('DELETE FROM codes WHERE expires_at < ?').run(now);
  db.prepare('DELETE FROM reset_tokens WHERE expires_at < ?').run(now);
  db.prepare('DELETE FROM sessions WHERE expires_at < ?').run(now);
  db.prepare('DELETE FROM throttle WHERE reset_at < ?').run(now);
  // Sign-ups nobody confirmed within a day.
  db.prepare('DELETE FROM users WHERE verified = 0 AND signup_at < ?').run(now - 24 * 60 * 60 * 1000);
}
