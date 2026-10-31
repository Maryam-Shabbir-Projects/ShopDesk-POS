import pg from 'pg';

// BIGINT (timestamps in ms) comes back as a string by default. Make it a number.
pg.types.setTypeParser(20, (v) => Number(v));

const SCHEMA = `
CREATE TABLE IF NOT EXISTS users (
  id          UUID PRIMARY KEY,
  email       TEXT NOT NULL UNIQUE,
  pass_hash   TEXT NOT NULL,
  role        TEXT NOT NULL DEFAULT 'owner',
  verified    BOOLEAN NOT NULL DEFAULT FALSE,
  created_at  BIGINT NOT NULL,
  signup_at   BIGINT NOT NULL
);

-- At most one live code per (email, purpose). Only a keyed hash is stored.
CREATE TABLE IF NOT EXISTS codes (
  email       TEXT NOT NULL,
  purpose     TEXT NOT NULL,            -- 'signup' | 'reset'
  code_hash   TEXT NOT NULL,
  expires_at  BIGINT NOT NULL,
  attempts    INTEGER NOT NULL DEFAULT 0,
  sent_at     BIGINT NOT NULL,
  PRIMARY KEY (email, purpose)
);

-- Proof that the reset code was entered. Single use, short life.
CREATE TABLE IF NOT EXISTS reset_tokens (
  token_hash  TEXT PRIMARY KEY,
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  expires_at  BIGINT NOT NULL
);

CREATE TABLE IF NOT EXISTS sessions (
  id          UUID PRIMARY KEY,
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash  TEXT NOT NULL UNIQUE,
  expires_at  BIGINT NOT NULL,
  revoked     BOOLEAN NOT NULL DEFAULT FALSE,
  created_at  BIGINT NOT NULL
);
CREATE INDEX IF NOT EXISTS sessions_user ON sessions(user_id);

-- Generic counter used for "too many sends / too many wrong passwords".
CREATE TABLE IF NOT EXISTS throttle (
  key         TEXT PRIMARY KEY,
  count       INTEGER NOT NULL,
  reset_at    BIGINT NOT NULL
);
`;

/**
 * Opens a connection pool. Neon: use the connection string from the Neon dashboard
 * (it ends in ?sslmode=require). Use the "pooled" one for a hosted server.
 */
export function openDb(connectionString, { max = 10 } = {}) {
  if (!connectionString) throw new Error('DATABASE_URL is not set');
  const pool = new pg.Pool({
    connectionString,
    max,
    idleTimeoutMillis: 30_000,
    connectionTimeoutMillis: 15_000, // Neon can take a few seconds to wake after being idle
  });
  // An idle connection dropped by Neon must not crash the process. The pool replaces it.
  pool.on('error', (e) => console.error('Database connection error:', e.message));
  return pool;
}

/** Creates the tables if they are missing. Safe to run on every start. */
export async function migrate(db) {
  await db.query(SCHEMA);
}

/** Runs a query, returns all rows. */
export async function rows(db, sql, params = []) {
  return (await db.query(sql, params)).rows;
}

/** Runs a query, returns the first row or undefined. */
export async function one(db, sql, params = []) {
  return (await db.query(sql, params)).rows[0];
}

/** Runs `fn(client)` in one transaction. Rolls back if it throws. */
export async function tx(db, fn) {
  const client = await db.connect();
  try {
    await client.query('BEGIN');
    const result = await fn(client);
    await client.query('COMMIT');
    return result;
  } catch (e) {
    await client.query('ROLLBACK').catch(() => {});
    throw e;
  } finally {
    client.release();
  }
}

/**
 * Counts one hit for `key` in one atomic statement. Returns true while the count is
 * within `limit` for the current window, false once it is exceeded.
 */
export async function hit(db, key, limit, windowMs, now = Date.now()) {
  const row = await one(
    db,
    `INSERT INTO throttle (key, count, reset_at) VALUES ($1, 1, $2)
     ON CONFLICT (key) DO UPDATE SET
       count    = CASE WHEN throttle.reset_at <= $3 THEN 1 ELSE throttle.count + 1 END,
       reset_at = CASE WHEN throttle.reset_at <= $3 THEN $2 ELSE throttle.reset_at END
     RETURNING count`,
    [key, now + windowMs, now],
  );
  return row.count <= limit;
}

/** True when `key` has already used up `limit` hits in the current window. */
export async function isBlocked(db, key, limit, now = Date.now()) {
  const row = await one(db, 'SELECT count, reset_at FROM throttle WHERE key = $1', [key]);
  return !!row && row.reset_at > now && row.count >= limit;
}

export async function clearKey(db, key) {
  await db.query('DELETE FROM throttle WHERE key = $1', [key]);
}

export async function purgeExpired(db, now = Date.now()) {
  await db.query('DELETE FROM codes WHERE expires_at < $1', [now]);
  await db.query('DELETE FROM reset_tokens WHERE expires_at < $1', [now]);
  await db.query('DELETE FROM sessions WHERE expires_at < $1', [now]);
  await db.query('DELETE FROM throttle WHERE reset_at < $1', [now]);
  // Sign-ups nobody confirmed within a day.
  await db.query('DELETE FROM users WHERE verified = FALSE AND signup_at < $1', [now - 24 * 60 * 60 * 1000]);
}
