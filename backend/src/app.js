// Entry point for VERCEL (and any host that wants "a module that exports the app").
// For your own server, Docker, or local use, the entry is src/local.js instead.
//
// Vercel looks for src/app.js and needs a default export that handles requests.
import { waitUntil } from '@vercel/functions';
import { loadConfig } from './config.js';
import { openDb, migrate, purgeExpired } from './db.js';
import { createMailer } from './mailer.js';
import { createApp } from './create-app.js';

let ready; // set on the first request of each cold start

async function init() {
  // Several short-lived copies of this function can run at once, so keep each pool tiny.
  // Use Neon's POOLED connection string so Neon (not each copy) manages the real connections.
  const config = loadConfig({ trustProxy: 1 });
  const db = openDb(config.databaseUrl, { max: 3 });
  await migrate(db); // creates the tables the first time; does nothing after that
  purgeExpired(db).catch((e) => console.error('Cleanup failed:', e.message));
  return createApp({ config, db, mailer: createMailer(config), background: waitUntil });
}

export default async function handler(req, res) {
  try {
    ready ??= init();
    const app = await ready;
    return app(req, res);
  } catch (e) {
    ready = undefined; // try again on the next request (for example if the database was asleep)
    console.error('Startup failed:', e.message);
    res.statusCode = 500;
    res.setHeader('content-type', 'application/json');
    res.end(JSON.stringify({ error: { code: 'server_error', message: 'Server is starting. Please try again.' } }));
  }
}
