// Entry point for VERCEL. Vercel looks for src/app.js, checks that it imports express,
// and uses its default export to answer requests.
// For your own server, Docker, or local use, the entry is src/local.js instead.
import express from 'express';
import { waitUntil } from '@vercel/functions';
import { loadConfig } from './config.js';
import { openDb, migrate, purgeExpired } from './db.js';
import { createMailer } from './mailer.js';
import { createApp } from './create-app.js';

let ready; // the real app, built on the first request of each cold start

async function init() {
  // Several short-lived copies of this function can run at once, so keep each pool tiny.
  // Use Neon's POOLED connection string so Neon (not each copy) manages the real connections.
  const config = loadConfig({ trustProxy: 1 });
  const db = openDb(config.databaseUrl, { max: 3 });
  await migrate(db); // creates the tables the first time; does nothing after that
  purgeExpired(db).catch((e) => console.error('Cleanup failed:', e.message));
  return createApp({ config, db, mailer: createMailer(config), background: waitUntil });
}

const app = express();
app.disable('x-powered-by');
app.use(async (req, res, next) => {
  try {
    ready ??= init();
    const real = await ready;
    real(req, res, next);
  } catch (e) {
    ready = undefined; // try again on the next request (for example if the database was asleep)
    console.error('Startup failed:', e.message);
    res.status(500).json({ error: { code: 'server_error', message: 'Server is starting. Please try again.' } });
  }
});

export default app;
