import express from 'express';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import jwt from 'jsonwebtoken';
import { hit, isBlocked, clearKey, one, tx } from './db.js';
import {
  hashPassword, verifyPassword, burnPasswordCheck, newCode, hashCode, safeEqualHex,
  randomToken, sha256, newId, normalizeEmail, isValidEmail, passwordProblem,
} from './security.js';

const HOUR = 60 * 60 * 1000;

/** Error codes match the app's AuthFailureKind (see lib/features/auth/domain/auth_failure.dart). */
const ERRORS = {
  invalid_request: [400, 'The request is not valid.'],
  invalid_credentials: [401, 'Email or password is incorrect.'],
  email_not_verified: [403, 'Please verify your email first.'],
  invalid_code: [400, 'That code is not correct. Check it and try again.'],
  code_expired: [400, 'That code has expired. Request a new one.'],
  too_many_attempts: [429, 'Too many wrong tries. Request a new code.'],
  rate_limited: [429, 'Too many requests. Please wait a minute and try again.'],
  weak_password: [400, 'That password is too weak. Use 8 or more characters with letters and numbers.'],
  sign_up_closed: [403, 'Creating new accounts is turned off for this shop.'],
  unauthorized: [401, 'Please sign in again.'],
  not_found: [404, 'Not found.'],
  server_error: [500, 'Something went wrong. Please try again.'],
};

class ApiError extends Error {
  constructor(code, message) {
    super(message ?? ERRORS[code][1]);
    this.code = code;
    this.status = ERRORS[code][0];
  }
}

const wrap = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);

/**
 * `background(promise)` keeps work alive after the response is sent. On a normal server this does
 * nothing (the promise just runs). On Vercel it is `waitUntil`, because a serverless function is
 * frozen the moment it answers and an unfinished email would never be sent.
 */
export function createApp({ config, db, mailer, now = () => Date.now(), background = () => {} }) {
  const app = express();
  app.disable('x-powered-by');
  if (config.trustProxy) app.set('trust proxy', config.trustProxy);
  app.use(helmet());
  app.use(express.json({ limit: '10kb' }));

  // ---------- helpers ----------
  const publicUser = (u) => ({ id: u.id, email: u.email, role: u.role });
  const userByEmail = (email) => one(db, 'SELECT * FROM users WHERE email = $1', [email]);
  const userById = (id) => one(db, 'SELECT * FROM users WHERE id = $1', [id]);

  function body(req) {
    return req.body && typeof req.body === 'object' && !Array.isArray(req.body) ? req.body : {};
  }

  function emailFrom(req) {
    const email = normalizeEmail(body(req).email);
    if (!isValidEmail(email)) throw new ApiError('invalid_request', 'Enter a valid email.');
    return email;
  }

  function newPasswordFrom(value) {
    const problem = passwordProblem(value);
    if (problem) throw new ApiError('weak_password', problem);
    return value;
  }

  /**
   * Cooldown and hourly cap on emails. Counted for EVERY address, known or not,
   * so the answer never shows whether an account exists.
   */
  async function allowSend(email, purpose) {
    const t = now();
    const okCooldown = await hit(db, `cool:${purpose}:${email}`, 1, config.resendCooldownMs, t);
    const okHour = await hit(db, `hour:${purpose}:${email}`, config.maxCodesPerHour, HOUR, t);
    if (!okCooldown || !okHour) throw new ApiError('rate_limited');
  }

  async function issueCode(email, purpose) {
    const code = newCode();
    const t = now();
    await db.query(
      `INSERT INTO codes (email, purpose, code_hash, expires_at, attempts, sent_at)
       VALUES ($1, $2, $3, $4, 0, $5)
       ON CONFLICT (email, purpose) DO UPDATE SET
         code_hash = EXCLUDED.code_hash, expires_at = EXCLUDED.expires_at,
         attempts = 0, sent_at = EXCLUDED.sent_at`,
      [email, purpose, hashCode(config.codeSecret, email, purpose, code), t + config.codeLifetimeMs, t],
    );
    // Not awaited: an account that exists and one that does not take the same time to answer.
    background(mailer.sendCode(email, purpose, code).catch((e) => console.error('Could not send email:', e.message)));
  }

  /**
   * Throws unless `code` is the live code. Every try is counted in the same statement that
   * reads the row, so parallel guesses cannot beat the 5-try limit. The right code is deleted
   * with a conditional DELETE, so two requests cannot both use it.
   */
  async function consumeCode(email, purpose, code) {
    if (typeof code !== 'string' || !/^\d{6}$/.test(code.trim())) throw new ApiError('invalid_code');
    const row = await one(
      db,
      'UPDATE codes SET attempts = attempts + 1 WHERE email = $1 AND purpose = $2 RETURNING *',
      [email, purpose],
    );
    if (!row) throw new ApiError('invalid_code');
    const drop = () => db.query('DELETE FROM codes WHERE email = $1 AND purpose = $2', [email, purpose]);
    if (now() > row.expires_at) { await drop(); throw new ApiError('code_expired'); }
    if (row.attempts > config.codeMaxAttempts) { await drop(); throw new ApiError('too_many_attempts'); }
    const given = hashCode(config.codeSecret, email, purpose, code.trim());
    if (!safeEqualHex(given, row.code_hash)) throw new ApiError('invalid_code');
    const used = await one(
      db,
      'DELETE FROM codes WHERE email = $1 AND purpose = $2 AND code_hash = $3 RETURNING 1 AS ok',
      [email, purpose, row.code_hash],
    );
    if (!used) throw new ApiError('invalid_code'); // someone else used it a moment ago
  }

  async function startSession(user, client = db) {
    const refreshToken = randomToken();
    const t = now();
    await client.query(
      'INSERT INTO sessions (id, user_id, token_hash, expires_at, revoked, created_at) VALUES ($1, $2, $3, $4, FALSE, $5)',
      [newId(), user.id, sha256(refreshToken), t + config.refreshTokenDays * 24 * HOUR, t],
    );
    const accessToken = jwt.sign({ role: user.role }, config.jwtSecret, {
      algorithm: 'HS256',
      subject: user.id,
      expiresIn: config.accessTokenSeconds,
      issuer: 'shopdesk',
    });
    return { user: publicUser(user), accessToken, refreshToken, expiresIn: config.accessTokenSeconds };
  }

  const revokeAllSessions = (userId, client = db) =>
    client.query('UPDATE sessions SET revoked = TRUE WHERE user_id = $1', [userId]);

  /** For future protected routes: `app.get('/shop/...', requireAuth, ...)`. */
  async function requireAuth(req, _res, next) {
    const header = req.get('authorization') ?? '';
    const token = header.startsWith('Bearer ') ? header.slice(7) : '';
    try {
      const payload = jwt.verify(token, config.jwtSecret, { algorithms: ['HS256'], issuer: 'shopdesk' });
      const user = await userById(payload.sub);
      if (!user || !user.verified) throw new Error('no user');
      req.user = user;
      next();
    } catch {
      next(new ApiError('unauthorized'));
    }
  }

  // ---------- per-IP limits (the per-email limits are above) ----------
  const ipLimiter = (max) =>
    config.ipRateLimit
      ? rateLimit({
          windowMs: 15 * 60 * 1000,
          limit: max,
          standardHeaders: true,
          legacyHeaders: false,
          handler: (_req, res) =>
            res.status(429).json({ error: { code: 'rate_limited', message: ERRORS.rate_limited[1] } }),
        })
      : (_req, _res, next) => next();

  const auth = express.Router();
  auth.use(ipLimiter(200));
  const strict = ipLimiter(40); // anything that guesses or sends

  // ---------- 1. Sign up: create an unverified account and email a code ----------
  auth.post('/signup', strict, wrap(async (req, res) => {
    const email = emailFrom(req);
    const password = newPasswordFrom(body(req).password);
    await allowSend(email, 'signup');
    const hash = await hashPassword(password); // always computed: same timing either way

    const owner = await one(db, 'SELECT 1 AS x FROM users WHERE verified = TRUE LIMIT 1');
    if (config.ownerOnly && owner) throw new ApiError('sign_up_closed');

    const t = now();
    const created = await one(
      db,
      `INSERT INTO users (id, email, pass_hash, role, verified, created_at, signup_at)
       VALUES ($1, $2, $3, 'owner', FALSE, $4, $4) ON CONFLICT (email) DO NOTHING RETURNING id`,
      [newId(), email, hash, t],
    );
    if (!created) {
      const existing = await userByEmail(email);
      if (existing?.verified) {
        // Never reveal that the address already has an account. No email is sent.
        return res.json({ ok: true });
      }
      // Retrying sign-up. Inside the code lifetime the original password is kept, so a stranger
      // cannot swap it before the real person types the code they were emailed.
      if (existing && t - existing.signup_at >= config.codeLifetimeMs) {
        await db.query('UPDATE users SET pass_hash = $1, signup_at = $2 WHERE id = $3', [hash, t, existing.id]);
      }
    }
    await issueCode(email, 'signup');
    res.json({ ok: true });
  }));

  // ---------- 2. Check the sign-up code: verified + signed in ----------
  auth.post('/verify-signup', strict, wrap(async (req, res) => {
    const email = emailFrom(req);
    await consumeCode(email, 'signup', body(req).code);
    const user = await userByEmail(email);
    if (!user) throw new ApiError('invalid_code');
    // One transaction with a lock, so two people verifying at the same moment cannot both become owner.
    const session = await tx(db, async (client) => {
      await client.query('SELECT pg_advisory_xact_lock(7001)');
      if (config.ownerOnly) {
        const other = await client.query('SELECT 1 FROM users WHERE verified = TRUE AND id != $1 LIMIT 1', [user.id]);
        if (other.rowCount) {
          await client.query('DELETE FROM users WHERE id = $1', [user.id]); // someone else became the owner first
          return null;
        }
      }
      await client.query('UPDATE users SET verified = TRUE WHERE id = $1', [user.id]);
      return startSession({ ...user, verified: true }, client);
    });
    if (!session) throw new ApiError('sign_up_closed');
    res.json(session);
  }));

  auth.post('/resend-signup', strict, wrap(async (req, res) => {
    const email = emailFrom(req);
    await allowSend(email, 'signup');
    const user = await userByEmail(email);
    if (user && !user.verified) await issueCode(email, 'signup');
    res.json({ ok: true });
  }));

  // ---------- 3. Sign in ----------
  auth.post('/signin', strict, wrap(async (req, res) => {
    const email = emailFrom(req);
    const password = typeof body(req).password === 'string' ? body(req).password.slice(0, 200) : '';
    const key = `login:${email}`;
    if (await isBlocked(db, key, config.maxSignInFailures, now())) throw new ApiError('rate_limited');

    const user = await userByEmail(email);
    const ok = user ? await verifyPassword(password, user.pass_hash) : (await burnPasswordCheck(password), false);
    if (!ok) {
      await hit(db, key, config.maxSignInFailures, 15 * 60 * 1000, now());
      throw new ApiError('invalid_credentials');
    }
    await clearKey(db, key);
    // Only said after the password is right, so it does not reveal who has an account.
    if (!user.verified) throw new ApiError('email_not_verified');
    res.json(await startSession(user));
  }));

  // ---------- 4. Forgot password ----------
  // Same answer whether or not the account exists.
  auth.post('/forgot', strict, wrap(async (req, res) => {
    const email = emailFrom(req);
    await allowSend(email, 'reset');
    const user = await userByEmail(email);
    if (user?.verified) await issueCode(email, 'reset');
    res.json({ ok: true });
  }));

  // Check the code. The reset token is the proof for the next step.
  auth.post('/verify-reset', strict, wrap(async (req, res) => {
    const email = emailFrom(req);
    await consumeCode(email, 'reset', body(req).code);
    const user = await userByEmail(email);
    if (!user?.verified) throw new ApiError('invalid_code');
    const resetToken = randomToken();
    await tx(db, async (client) => {
      await client.query('DELETE FROM reset_tokens WHERE user_id = $1', [user.id]);
      await client.query('INSERT INTO reset_tokens (token_hash, user_id, expires_at) VALUES ($1, $2, $3)', [
        sha256(resetToken), user.id, now() + config.resetTokenMs,
      ]);
    });
    res.json({ resetToken, expiresIn: Math.round(config.resetTokenMs / 1000) });
  }));

  // Only reachable with a reset token, i.e. after the right code.
  auth.post('/reset-password', strict, wrap(async (req, res) => {
    const { resetToken } = body(req);
    const password = newPasswordFrom(body(req).newPassword);
    const expired = () => new ApiError('unauthorized', 'This reset has expired. Please start again.');
    if (typeof resetToken !== 'string' || !resetToken) throw expired();
    // Taking the token and deleting it is one statement: it can only be used once.
    const row = await one(db, 'DELETE FROM reset_tokens WHERE token_hash = $1 RETURNING *', [sha256(resetToken)]);
    if (!row || row.expires_at < now()) throw expired();
    const hash = await hashPassword(password);
    const session = await tx(db, async (client) => {
      await client.query('UPDATE users SET pass_hash = $1, verified = TRUE WHERE id = $2', [hash, row.user_id]);
      await revokeAllSessions(row.user_id, client); // a changed password signs every other phone out
      const user = (await client.query('SELECT * FROM users WHERE id = $1', [row.user_id])).rows[0];
      return startSession(user, client);
    });
    res.json(session);
  }));

  // ---------- 5. Keep the session alive / sign out / who am I ----------
  auth.post('/refresh', wrap(async (req, res) => {
    const token = body(req).refreshToken;
    if (typeof token !== 'string' || !token) throw new ApiError('unauthorized');
    const hash = sha256(token);
    // Rotate: mark this token used, only if it was still unused.
    const row = await one(
      db,
      'UPDATE sessions SET revoked = TRUE WHERE token_hash = $1 AND revoked = FALSE RETURNING *',
      [hash],
    );
    if (!row) {
      const old = await one(db, 'SELECT user_id FROM sessions WHERE token_hash = $1', [hash]);
      // An old token came back: it may have been stolen. End every session for this account.
      if (old) await revokeAllSessions(old.user_id);
      throw new ApiError('unauthorized');
    }
    const user = await userById(row.user_id);
    if (row.expires_at < now() || !user?.verified) throw new ApiError('unauthorized');
    res.json(await startSession(user));
  }));

  auth.post('/signout', wrap(async (req, res) => {
    const token = body(req).refreshToken;
    if (typeof token === 'string' && token) {
      await db.query('UPDATE sessions SET revoked = TRUE WHERE token_hash = $1', [sha256(token)]);
    }
    res.status(204).end();
  }));

  auth.get('/me', requireAuth, (req, res) => res.json({ user: publicUser(req.user) }));

  // Also checks the database, so a hosting health check notices a broken connection.
  app.get('/health', wrap(async (_req, res) => {
    await db.query('SELECT 1');
    res.json({ ok: true });
  }));
  app.use('/auth', auth);

  app.use((_req, _res, next) => next(new ApiError('not_found')));
  // eslint-disable-next-line no-unused-vars
  app.use((err, _req, res, _next) => {
    if (err instanceof ApiError) {
      return res.status(err.status).json({ error: { code: err.code, message: err.message } });
    }
    if (err?.type === 'entity.parse.failed' || err?.type === 'entity.too.large') {
      return res.status(400).json({ error: { code: 'invalid_request', message: ERRORS.invalid_request[1] } });
    }
    console.error(err);
    res.status(500).json({ error: { code: 'server_error', message: ERRORS.server_error[1] } });
  });

  app.locals.requireAuth = requireAuth;
  return app;
}
