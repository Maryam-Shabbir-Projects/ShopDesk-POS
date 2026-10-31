import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

/**
 * A real Postgres for the tests.
 *  - TEST_DATABASE_URL set  -> uses that database (its tables are emptied by the tests,
 *    so point it at a throw-away database, NEVER at your real Neon one).
 *  - otherwise              -> starts a temporary Postgres (embedded-postgres), removed afterwards.
 *    It cannot run as the root user; use a normal account.
 */
export async function startTestDatabase() {
  if (process.env.TEST_DATABASE_URL) {
    return { url: process.env.TEST_DATABASE_URL, stop: async () => {} };
  }
  const { default: EmbeddedPostgres } = await import('embedded-postgres');
  const dir = mkdtempSync(join(tmpdir(), 'shopdesk-pg-'));
  const port = 54000 + Math.floor(Math.random() * 1000);
  const pg = new EmbeddedPostgres({
    databaseDir: dir, user: 'postgres', password: 'test', port, persistent: false,
    onLog: () => {}, onError: () => {},
  });
  await pg.initialise();
  await pg.start();
  return {
    url: `postgres://postgres:test@127.0.0.1:${port}/postgres`,
    stop: async () => { await pg.stop(); rmSync(dir, { recursive: true, force: true }); },
  };
}
