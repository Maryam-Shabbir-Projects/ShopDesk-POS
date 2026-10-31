import { loadConfig } from './config.js';
import { openDb, purgeExpired } from './db.js';
import { createMailer } from './mailer.js';
import { createApp } from './app.js';

const config = loadConfig();
const db = openDb(config.dbPath);
const app = createApp({ config, db, mailer: createMailer(config) });

purgeExpired(db);
const cleaner = setInterval(() => purgeExpired(db), 60 * 60 * 1000);
cleaner.unref();

const server = app.listen(config.port, () => {
  console.log(`ShopDesk auth server on :${config.port} (${config.nodeEnv}, ownerOnly=${config.ownerOnly})`);
  if (!config.smtp.host) console.log('No SMTP_HOST set: codes are printed here instead of emailed.');
});

const stop = () => server.close(() => { db.close(); process.exit(0); });
process.on('SIGINT', stop);
process.on('SIGTERM', stop);
