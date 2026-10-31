import { loadConfig } from './config.js';
import { openDb, migrate, purgeExpired } from './db.js';
import { createMailer } from './mailer.js';
import { createApp } from './create-app.js';

const config = loadConfig();
const db = openDb(config.databaseUrl);
await migrate(db); // creates the tables on first start; does nothing after that
const app = createApp({ config, db, mailer: createMailer(config) });

const clean = () => purgeExpired(db).catch((e) => console.error('Cleanup failed:', e.message));
await clean();
const cleaner = setInterval(clean, 60 * 60 * 1000);
cleaner.unref();

const server = app.listen(config.port, () => {
  console.log(`ShopDesk auth server on :${config.port} (${config.nodeEnv}, ownerOnly=${config.ownerOnly}, db=postgres)`);
  if (!config.smtp.host) console.log('No SMTP_HOST set: codes are printed here instead of emailed.');
});

const stop = () => server.close(async () => { await db.end(); process.exit(0); });
process.on('SIGINT', stop);
process.on('SIGTERM', stop);
