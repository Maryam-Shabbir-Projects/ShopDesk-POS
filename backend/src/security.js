import crypto from 'node:crypto';
import { promisify } from 'node:util';

const scrypt = promisify(crypto.scrypt);
const KEYLEN = 64;
const N = 16384;

/** scrypt$N$salt$hash. Slow on purpose, salted per password. */
export async function hashPassword(password) {
  const salt = crypto.randomBytes(16);
  const hash = await scrypt(password, salt, KEYLEN, { N, r: 8, p: 1 });
  return `scrypt$${N}$${salt.toString('base64url')}$${hash.toString('base64url')}`;
}

export async function verifyPassword(password, stored) {
  const [scheme, n, salt, hash] = String(stored).split('$');
  if (scheme !== 'scrypt') return false;
  const expected = Buffer.from(hash, 'base64url');
  const actual = await scrypt(password, Buffer.from(salt, 'base64url'), expected.length, {
    N: Number(n),
    r: 8,
    p: 1,
  });
  return crypto.timingSafeEqual(actual, expected);
}

// Used when the email is unknown so a wrong email takes as long as a wrong password.
let dummy;
export async function burnPasswordCheck(password) {
  dummy ??= await hashPassword('dummy-password-1');
  await verifyPassword(password, dummy);
}

export function newCode() {
  return String(crypto.randomInt(100000, 1000000));
}

/** Keyed hash (HMAC), so a stolen database alone cannot reveal or guess codes offline. */
export function hashCode(secret, email, purpose, code) {
  return crypto.createHmac('sha256', secret).update(`${email}\n${purpose}\n${code}`).digest('hex');
}

export function safeEqualHex(a, b) {
  const x = Buffer.from(a, 'hex');
  const y = Buffer.from(b, 'hex');
  return x.length === y.length && crypto.timingSafeEqual(x, y);
}

export const randomToken = () => crypto.randomBytes(32).toString('base64url');
export const sha256 = (value) => crypto.createHash('sha256').update(value).digest('hex');
export const newId = () => crypto.randomUUID();

// ---- Input rules. Same as the app's AuthValidators; the server must not trust the app. ----
const EMAIL = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

export const normalizeEmail = (v) => (typeof v === 'string' ? v.trim().toLowerCase() : '');

export function isValidEmail(email) {
  return email.length > 0 && email.length <= 254 && EMAIL.test(email);
}

/** Returns an error message or null. */
export function passwordProblem(p) {
  if (typeof p !== 'string' || p.length < 8) return 'Use at least 8 characters';
  if (p.length > 128) return 'Use at most 128 characters';
  if (!/[A-Za-z]/.test(p) || !/\d/.test(p)) return 'Include at least one letter and one number';
  return null;
}
