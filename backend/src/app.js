import express from 'express';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import jwt from 'jsonwebtoken';
import { hit, isBlocked, clearKey } from './db.js';
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

export function createApp({ config, db, mailer, now = () => Date.now() }) {
  const app = express();
  app.disable('x-powered-by');
  if (config.trustProxy) app.set('trust proxy', config.trustProxy);
  app.use(helmet());
  app.use(express.json({ limit: '10kb' }));

  // ---------- helpers ----------
  const publicUser = (u) => ({ id: u.id, email: u.email, role: u.role });
  const userByEmail = (email) => db.prepare('SELECT * FROM users WHERE email = ?').get(email);
  const userById = (id) => db.prepare('SELECT * FROM users WHERE id = ?').get(id);

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
  function allowSend(email, purpose) {
    const t = now();
    const okCooldown = hit(db, `cool:${purpose}:${email}`, 1, config.resendCooldownMs, t);
    const okHour = hit(db, `hour:${purpose}:${email}`, config.maxCodesPerHour, HOUR, t);
    if (!okCooldown || !okHour) throw new ApiError('rate_limited');
  }

  function issueCode(email, purpose) {
    const code = newCode();
    const t = now();
    db.prepare(
      `INSERT OR REPLACE INTO codes (email, purpose, code_hash, expires_at, attempts, sent_at)
       VALUES (?, ?, ?, ?, 0, ?)`,
    ).run(email, purpose, hashCode(config.codeSecret, email, purpose, code), t + config.codeLifetimeMs, t);
    // Not awaited: an account that exists and one that does not take the same time to answer.
    mailer.sendCode(email, purpose, code).catch((e) => console.error('Could not send email:', e.message));
  }

  /** Throws unless `code` is the live code. Wrong tries are counted; right code is single use. */
  function consumeCode(email, purpose, code) {
    if (typeof code !== 'string' || !/^\d{6}$/.test(code.trim())) throw new ApiError('invalid_code');
    const row = db.prepare('SELECT * FROM codes WHERE email = ? AND purpose = ?').get(email, purpose);
    if (!row) throw new ApiError('invalid_code');
    const drop = () => db.prepare('DELETE FROM codes WHERE email = ? AND purpose = ?').run(email, purpose);
    if (now() > row.expires_at) { drop(); throw new ApiError('code_expired'); }
    if (row.attempts >= config.codeMaxAttempts) { drop(); throw new ApiError('too_many_attempts'); }
    db.prepare('UPDATE codes SET attempts = attempts + 1 WHERE email = ? AND purpose = ?').run(email, purpose);
    const given = hashCode(config.codeSecret, email, purpose, code.trim());
    if (!safeEqualHex(given, row.code_hash)) throw new ApiError('invalid_code');
    drop();
  }

  function startSession(user) {
    const refreshToken = randomToken();
    const t = now();
    db.prepare(
      'INSERT INTO sessions (id, user_id, token_hash, expires_at, revoked, created_at) VALUES (?, ?, ?, ?, 0, ?)',
    ).run(newId(), user.id, sha256(refreshToken), t + config.refreshTokenDays * 24 * HOUR, t);
    const accessToken = jwt.sign({ role: user.role }, config.jwtSecret, {
      algorithm: 'HS256',
      subject: user.id,
      expiresIn: config.accessTokenSeconds,
      issuer: 'shopdesk',
    });
    return { user: publicUser(user), accessToken, refreshToken, expiresIn: config.accessTokenSeconds };
  }

  const revokeAllSessions = (userId) =>
    db.prepare('UPDATE sessions SET revoked = 1 WHERE user_id = ?').run(userId);

  /** For future protected routes: `app.get('/shop/...', requireAuth, ...)`. */
  function requireAuth(req, _res, next) {
    const header = req.get('authorization') ?? '';
    const token = header.startsWith('Bearer ') ? header.slice(7) : '';
    try {
      const payload = jwt.verify(token, config.jwtSecret, { algorithms: ['HS256'], issuer: 'shopdesk' });
      const user = userById(payload.sub);
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
    allowSend(email, 'signup');
    const hash = await hashPassword(password); // always computed: same timing either way

    const owner = db.prepare('SELECT 1 AS x FROM users WHERE verified = 1 LIMIT 1').get();
    if (config.ownerOnly && owner) throw new ApiError('sign_up_closed');

    const existing = userByEmail(email);
    const t = now();
    if (existing?.verified) {
      // Never reveal that the address already has an account. No email is sent.
      return res.json({ ok: true });
    }
    if (existing) {
      // Retrying sign-up. Inside the code lifetime the original password is kept, so a stranger
      // cannot swap it before the real person types the code they were emailed.
      if (t - existing.signup_at >= config.codeLifetimeMs) {
        db.prepare('UPDATE users SET pass_hash = ?, signup_at = ? WHERE id = ?').run(hash, t, existing.id);
      }
    } else {
      db.prepare(
        'INSERT INTO users (id, email, pass_hash, role, verified, created_at, signup_at) VALUES (?, ?, ?, ?, 0, ?, ?)',
      ).run(newId(), email, hash, 'owner', t, t);
    }
    issueCode(email, 'signup');
    res.json({ ok: true });
  }));

  // ---------- 2. Check the sign-up code: verified + signed in ----------
  auth.post('/verify-signup', strict, wrap(async (req, res) => {
    const email = emailFrom(req);
    consumeCode(email, 'signup', body(req).code);
    const user = userByEmail(email);
    if (!user) throw new ApiError('invalid_code');
    if (config.ownerOnly && db.prepare('SELECT 1 AS x FROM users WHERE verified = 1 AND id != ?').get(user.id)) {
      db.prepare('DELETE FROM users WHERE id = ?').run(user.id); // someone else became the owner first
      throw new ApiError('sign_up_closed');
    }
    db.prepare('UPDATE users SET verified = 1 WHERE id = ?').run(user.id);
    res.json(startSession({ ...user, verified: 1 }));
  }));

  auth.post('/resend-signup', strict, wrap(async (req, res) => {
    const email = emailFrom(req);
    allowSend(email, 'signup');
    const user = userByEmail(email);
    if (user && !user.verified) issueCode(email, 'signup');
    res.json({ ok: true });
  }));

  // ---------- 3. Sign in ----------
  auth.post('/signin', strict, wrap(async (req, res) => {
    const email = emailFrom(req);
    const password = typeof body(req).password === 'string' ? body(req).password.slice(0, 200) : '';
    const key = `login:${email}`;
    if (isBlocked(db, key, config.maxSignInFailures, now())) throw new ApiError('rate_limited');

    const user = userByEmail(email);
    const ok = user ? await verifyPassword(password, user.pass_hash) : (await burnPasswordCheck(password), false);
    if (!ok) {
      hit(db, key, config.maxSignInFailures, 15 * 60 * 1000, now());
      throw new ApiError('invalid_credentials');
    }
    clearKey(db, key);
    // Only said after the password is right, so it does not reveal who has an account.
    if (!user.verified) throw new ApiError('email_not_verified');
    res.json(startSession(user));
  }));

  // ---------- 4. Forgot password ----------
  // Same answer whether or not the account exists.
  auth.post('/forgot', strict, wrap(async (req, res) => {
    const email = emailFrom(req);
    allowSend(email, 'reset');
    const user = userByEmail(email);
    if (user?.verified) issueCode(email, 'reset');
    res.json({ ok: true });
  }));

  // Check the code. The reset token is the proof for the next step.
  auth.post('/verify-reset', strict, wrap(async (req, res) => {
    const email = emailFrom(req);
    consumeCode(email, 'reset', body(req).code);
    const user = userByEmail(email);
    if (!user?.verified) throw new ApiError('invalid_code');
    const resetToken = randomToken();
    db.prepare('DELETE FROM reset_tokens WHERE user_id = ?').run(user.id);
    db.prepare('INSERT INTO reset_tokens (token_hash, user_id, expires_at) VALUES (?, ?, ?)').run(
      sha256(resetToken), user.id, now() + config.resetTokenMs,
    );
    res.json({ resetToken, expiresIn: Math.round(config.resetTokenMs / 1000) });
  }));

  // Only reachable with a reset token, i.e. after the right code.
  auth.post('/reset-password', strict, wrap(async (req, res) => {
    const { resetToken } = body(req);
    const password = newPasswordFrom(body(req).newPassword);
    if (typeof resetToken !== 'string' || !resetToken) throw new ApiError('unauthorized', 'This reset has expired. Please start again.');
    const row = db.prepare('SELECT * FROM reset_tokens WHERE token_hash = ?').get(sha256(resetToken));
    if (!row || row.expires_at < now()) {
      if (row) db.prepare('DELETE FROM reset_tokens WHERE token_hash = ?').run(row.token_hash);
      throw new ApiError('unauthorized', 'This reset has expired. Please start again.');
    }
    const hash = await hashPassword(password);
    db.prepare('DELETE FROM reset_tokens WHERE user_id = ?').run(row.user_id); // single use
    db.prepare('UPDATE users SET pass_hash = ?, verified = 1 WHERE id = ?').run(hash, row.user_id);
    revokeAllSessions(row.user_id); // a changed password signs every other phone out
    res.json(startSession(userById(row.user_id)));
  }));

  // ---------- 5. Keep the session alive / sign out / who am I ----------
  auth.post('/refresh', wrap(async (req, res) => {
    const token = body(req).refreshToken;
    if (typeof token !== 'string' || !token) throw new ApiError('unauthorized');
    const row = db.prepare('SELECT * FROM sessions WHERE token_hash = ?').get(sha256(token));
    if (!row) throw new ApiError('unauthorized');
    if (row.revoked) {
      // An old token came back: it may have been stolen. End every session for this account.
      revokeAllSessions(row.user_id);
      throw new ApiError('unauthorized');
    }
    const user = userById(row.user_id);
    if (row.expires_at < now() || !user?.verified) throw new ApiError('unauthorized');
    db.prepare('UPDATE sessions SET revoked = 1 WHERE id = ?').run(row.id); // rotate
    res.json(startSession(user));
  }));

  auth.post('/signout', wrap(async (req, res) => {
    const token = body(req).refreshToken;
    if (typeof token === 'string' && token) {
      db.prepare('UPDATE sessions SET revoked = 1 WHERE token_hash = ?').run(sha256(token));
    }
    res.status(204).end();
  }));

  auth.get('/me', requireAuth, (req, res) => res.json({ user: publicUser(req.user) }));

  app.get('/health', (_req, res) => res.json({ ok: true }));
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
