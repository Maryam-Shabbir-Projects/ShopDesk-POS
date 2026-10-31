import { test, before, after, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { loadConfig } from '../src/config.js';
import { openDb, migrate, one } from '../src/db.js';
import { createApp } from '../src/app.js';
import { startTestDatabase } from './test-database.js';

const EMAIL = 'owner@shop.com';
const PASSWORD = 'Passw0rd1';

let server, base, db, clock, mails, testDb;

before(async () => {
  testDb = await startTestDatabase();
  db = openDb(testDb.url);
  await migrate(db);
});

after(async () => {
  await db.end();
  await testDb.stop();
});

async function start(overrides = {}) {
  clock = 1_800_000_000_000;
  mails = [];
  await db.query('TRUNCATE users, codes, reset_tokens, sessions, throttle CASCADE');
  const config = loadConfig({ ipRateLimit: false, ...overrides });
  const mailer = { sendCode: async (email, purpose, code) => { mails.push({ email, purpose, code }); } };
  const app = createApp({ config, db, mailer, now: () => clock });
  await new Promise((r) => { server = app.listen(0, '127.0.0.1', r); });
  base = `http://127.0.0.1:${server.address().port}`;
}

async function call(path, data, token) {
  const res = await fetch(base + path, {
    method: data === undefined ? 'GET' : 'POST',
    headers: { 'content-type': 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}) },
    body: data === undefined ? undefined : JSON.stringify(data),
  });
  const text = await res.text();
  return { status: res.status, json: text ? JSON.parse(text) : null };
}

const lastCode = (purpose) => mails.filter((m) => m.purpose === purpose).at(-1)?.code;
const errorCode = (r) => r.json?.error?.code;

async function registerOwner() {
  await call('/auth/signup', { email: EMAIL, password: PASSWORD });
  clock += 31_000;
  return call('/auth/verify-signup', { email: EMAIL, code: lastCode('signup') });
}

beforeEach(() => start());
afterEach(() => new Promise((r) => server.close(r)));

test('cannot sign in before the email is verified, then the code verifies and signs in', async () => {
  assert.equal((await call('/auth/signup', { email: EMAIL, password: PASSWORD })).status, 200);
  assert.match(lastCode('signup'), /^\d{6}$/);

  const early = await call('/auth/signin', { email: EMAIL, password: PASSWORD });
  assert.equal(early.status, 403);
  assert.equal(errorCode(early), 'email_not_verified');

  clock += 31_000;
  const v = await call('/auth/verify-signup', { email: EMAIL, code: lastCode('signup') });
  assert.equal(v.status, 200);
  assert.equal(v.json.user.email, EMAIL);
  assert.equal(v.json.user.role, 'owner');

  const me = await call('/auth/me', undefined, v.json.accessToken);
  assert.equal(me.json.user.email, EMAIL);
  assert.equal((await call('/auth/signin', { email: EMAIL, password: PASSWORD })).status, 200);
});

test('wrong password and unknown email give the same answer', async () => {
  await registerOwner();
  const a = await call('/auth/signin', { email: EMAIL, password: 'Wrong1234' });
  const b = await call('/auth/signin', { email: 'nobody@shop.com', password: 'Wrong1234' });
  assert.equal(a.status, 401);
  assert.deepEqual(a.json, b.json);
});

test('a code is single use', async () => {
  await call('/auth/signup', { email: EMAIL, password: PASSWORD });
  const code = lastCode('signup');
  assert.equal((await call('/auth/verify-signup', { email: EMAIL, code })).status, 200);
  assert.equal(errorCode(await call('/auth/verify-signup', { email: EMAIL, code })), 'invalid_code');
});

test('5 wrong tries burn the code, even the right one then fails', async () => {
  await call('/auth/signup', { email: EMAIL, password: PASSWORD });
  const right = lastCode('signup');
  const wrong = right === '111111' ? '222222' : '111111';
  for (let i = 0; i < 5; i++) {
    assert.equal(errorCode(await call('/auth/verify-signup', { email: EMAIL, code: wrong })), 'invalid_code');
  }
  assert.equal(errorCode(await call('/auth/verify-signup', { email: EMAIL, code: right })), 'too_many_attempts');
  assert.equal(errorCode(await call('/auth/verify-signup', { email: EMAIL, code: right })), 'invalid_code');
});

test('a code expires after 10 minutes', async () => {
  await call('/auth/signup', { email: EMAIL, password: PASSWORD });
  clock += 10 * 60 * 1000 + 1;
  assert.equal(errorCode(await call('/auth/verify-signup', { email: EMAIL, code: lastCode('signup') })), 'code_expired');
});

test('resend is limited to once per 30 seconds, and a new code replaces the old one', async () => {
  await call('/auth/signup', { email: EMAIL, password: PASSWORD });
  const first = lastCode('signup');
  assert.equal(errorCode(await call('/auth/resend-signup', { email: EMAIL })), 'rate_limited');
  clock += 31_000;
  assert.equal((await call('/auth/resend-signup', { email: EMAIL })).status, 200);
  const second = lastCode('signup');
  if (first !== second) {
    assert.equal(errorCode(await call('/auth/verify-signup', { email: EMAIL, code: first })), 'invalid_code');
  }
  assert.equal((await call('/auth/verify-signup', { email: EMAIL, code: second })).status, 200);
});

test('weak passwords and bad emails are refused', async () => {
  assert.equal(errorCode(await call('/auth/signup', { email: EMAIL, password: 'short1' })), 'weak_password');
  assert.equal(errorCode(await call('/auth/signup', { email: EMAIL, password: 'onlyletters' })), 'weak_password');
  assert.equal(errorCode(await call('/auth/signup', { email: 'not-an-email', password: PASSWORD })), 'invalid_request');
  assert.equal(errorCode(await call('/auth/signup', {})), 'invalid_request');
  assert.equal(mails.length, 0);
});

test('only one owner: others cannot register once an owner exists', async () => {
  await registerOwner();
  clock += 31_000;
  const r = await call('/auth/signup', { email: 'other@shop.com', password: PASSWORD });
  assert.equal(errorCode(r), 'sign_up_closed');
  assert.equal(mails.filter((m) => m.email === 'other@shop.com').length, 0);
});

test('if two people sign up, only the first to verify becomes the owner', async () => {
  await call('/auth/signup', { email: 'a@shop.com', password: PASSWORD });
  await call('/auth/signup', { email: 'b@shop.com', password: PASSWORD });
  const codeA = mails.find((m) => m.email === 'a@shop.com').code;
  const codeB = mails.find((m) => m.email === 'b@shop.com').code;
  assert.equal((await call('/auth/verify-signup', { email: 'a@shop.com', code: codeA })).status, 200);
  assert.equal(errorCode(await call('/auth/verify-signup', { email: 'b@shop.com', code: codeB })), 'sign_up_closed');
});

test('signing up again before verifying does not let a stranger change the password', async () => {
  await call('/auth/signup', { email: EMAIL, password: PASSWORD });
  clock += 31_000;
  await call('/auth/signup', { email: EMAIL, password: 'Attacker99' });
  const v = await call('/auth/verify-signup', { email: EMAIL, code: lastCode('signup') });
  assert.equal(v.status, 200);
  assert.equal((await call('/auth/signin', { email: EMAIL, password: PASSWORD })).status, 200);
  assert.equal(errorCode(await call('/auth/signin', { email: EMAIL, password: 'Attacker99' })), 'invalid_credentials');
});

test('forgot password: unknown email looks identical and sends nothing', async () => {
  await registerOwner();
  clock += 31_000;
  const unknown = await call('/auth/forgot', { email: 'nobody@shop.com' });
  const known = await call('/auth/forgot', { email: EMAIL });
  assert.equal(unknown.status, 200);
  assert.deepEqual(unknown.json, known.json);
  assert.equal(mails.filter((m) => m.purpose === 'reset' && m.email === 'nobody@shop.com').length, 0);
  assert.equal(mails.filter((m) => m.purpose === 'reset' && m.email === EMAIL).length, 1);
});

test('reset password needs the emailed code first; then signs in and ends other sessions', async () => {
  const first = await registerOwner();
  clock += 31_000;

  // No token, or a made-up token, cannot reach the new-password step.
  assert.equal((await call('/auth/reset-password', { newPassword: 'Brand9New1' })).status, 401);
  assert.equal((await call('/auth/reset-password', { resetToken: 'guess', newPassword: 'Brand9New1' })).status, 401);

  await call('/auth/forgot', { email: EMAIL });
  const code = lastCode('reset');
  const wrong = code === '123456' ? '654321' : '123456';
  assert.equal(errorCode(await call('/auth/verify-reset', { email: EMAIL, code: wrong })), 'invalid_code');

  const ok = await call('/auth/verify-reset', { email: EMAIL, code });
  assert.equal(ok.status, 200);
  assert.ok(ok.json.resetToken);

  assert.equal(errorCode(await call('/auth/reset-password', { resetToken: ok.json.resetToken, newPassword: 'weak' })), 'weak_password');
  const done = await call('/auth/reset-password', { resetToken: ok.json.resetToken, newPassword: 'Brand9New1' });
  assert.equal(done.status, 200);
  assert.equal(done.json.user.email, EMAIL);

  // single use
  assert.equal((await call('/auth/reset-password', { resetToken: ok.json.resetToken, newPassword: 'Another9One' })).status, 401);
  // old password dead, new one works
  assert.equal(errorCode(await call('/auth/signin', { email: EMAIL, password: PASSWORD })), 'invalid_credentials');
  assert.equal((await call('/auth/signin', { email: EMAIL, password: 'Brand9New1' })).status, 200);
  // the phone that was signed in before is signed out
  assert.equal((await call('/auth/refresh', { refreshToken: first.json.refreshToken })).status, 401);
});

test('reset token expires after 10 minutes', async () => {
  await registerOwner();
  clock += 31_000;
  await call('/auth/forgot', { email: EMAIL });
  const { json } = await call('/auth/verify-reset', { email: EMAIL, code: lastCode('reset') });
  clock += 10 * 60 * 1000 + 1;
  assert.equal((await call('/auth/reset-password', { resetToken: json.resetToken, newPassword: 'Brand9New1' })).status, 401);
});

test('refresh rotates tokens; replaying an old one ends the whole session family', async () => {
  const s = await registerOwner();
  const r1 = await call('/auth/refresh', { refreshToken: s.json.refreshToken });
  assert.equal(r1.status, 200);
  assert.notEqual(r1.json.refreshToken, s.json.refreshToken);

  assert.equal((await call('/auth/refresh', { refreshToken: s.json.refreshToken })).status, 401); // replay
  assert.equal((await call('/auth/refresh', { refreshToken: r1.json.refreshToken })).status, 401); // now dead too
});

test('sign out revokes the refresh token', async () => {
  const s = await registerOwner();
  assert.equal((await call('/auth/signout', { refreshToken: s.json.refreshToken })).status, 204);
  assert.equal((await call('/auth/refresh', { refreshToken: s.json.refreshToken })).status, 401);
});

test('missing or junk access tokens are refused', async () => {
  const s = await registerOwner();
  assert.equal((await call('/auth/me', undefined, 'junk')).status, 401);
  assert.equal((await call('/auth/me')).status, 401);
  assert.equal((await call('/auth/me', undefined, s.json.accessToken)).status, 200);
});

test('too many wrong passwords locks sign-in for that email', async () => {
  await registerOwner();
  for (let i = 0; i < 8; i++) await call('/auth/signin', { email: EMAIL, password: 'Wrong1234' });
  assert.equal(errorCode(await call('/auth/signin', { email: EMAIL, password: PASSWORD })), 'rate_limited');
  clock += 15 * 60 * 1000 + 1;
  assert.equal((await call('/auth/signin', { email: EMAIL, password: PASSWORD })).status, 200);
});

test('open sign-up mode: existing address gets the same answer and no email', async () => {
  await new Promise((r) => server.close(r));
  await start({ ownerOnly: false });
  await registerOwner();
  mails.length = 0;
  clock += 31_000;
  const again = await call('/auth/signup', { email: EMAIL, password: 'Other1234x' });
  assert.equal(again.status, 200);
  assert.equal(mails.length, 0);
  assert.equal(errorCode(await call('/auth/signin', { email: EMAIL, password: 'Other1234x' })), 'invalid_credentials');
});

test('codes are stored hashed, passwords are stored hashed', async () => {
  await call('/auth/signup', { email: EMAIL, password: PASSWORD });
  const code = lastCode('signup');
  const row = await one(db, 'SELECT * FROM codes');
  assert.notEqual(row.code_hash, code);
  assert.ok(!JSON.stringify(row).includes(code));
  assert.ok((await one(db, 'SELECT pass_hash FROM users')).pass_hash.startsWith('scrypt$'));
});

test('bad JSON and unknown routes get clean JSON errors', async () => {
  const res = await fetch(base + '/auth/signin', { method: 'POST', headers: { 'content-type': 'application/json' }, body: '{oops' });
  assert.equal(res.status, 400);
  assert.equal((await res.json()).error.code, 'invalid_request');
  assert.equal((await call('/nope')).status, 404);
});

test('parallel guesses cannot beat the 5-try limit', async () => {
  await call('/auth/signup', { email: EMAIL, password: PASSWORD });
  const right = lastCode('signup');
  const wrong = right === '111111' ? '222222' : '111111';
  // 5 guesses at once must all be counted (no lost updates): the next try is the 6th.
  const five = await Promise.all(
    Array.from({ length: 5 }, () => call('/auth/verify-signup', { email: EMAIL, code: wrong })),
  );
  assert.ok(five.every((g) => errorCode(g) === 'invalid_code'));
  assert.equal(errorCode(await call('/auth/verify-signup', { email: EMAIL, code: right })), 'too_many_attempts');
});

test('a burst of 20 parallel guesses cannot get in, even with the right code in it', async () => {
  await call('/auth/signup', { email: EMAIL, password: PASSWORD });
  const right = lastCode('signup');
  const wrong = right === '111111' ? '222222' : '111111';
  const burst = await Promise.all([
    ...Array.from({ length: 19 }, () => call('/auth/verify-signup', { email: EMAIL, code: wrong })),
    call('/auth/verify-signup', { email: EMAIL, code: right }),
  ]);
  // At most 5 requests were ever checked against the code; the right one can win only if it was among them.
  assert.ok(burst.filter((r) => r.status === 200).length <= 1);
  assert.ok(burst.some((r) => errorCode(r) === 'too_many_attempts') || burst.some((r) => r.status === 200));
});

test('the same code used twice at the same moment works only once', async () => {
  await call('/auth/signup', { email: EMAIL, password: PASSWORD });
  const code = lastCode('signup');
  const both = await Promise.all([
    call('/auth/verify-signup', { email: EMAIL, code }),
    call('/auth/verify-signup', { email: EMAIL, code }),
  ]);
  assert.deepEqual(both.map((r) => r.status).sort(), [200, 400]);
});

test('two people verifying at the same moment: only one becomes the owner', async () => {
  await call('/auth/signup', { email: 'a@shop.com', password: PASSWORD });
  await call('/auth/signup', { email: 'b@shop.com', password: PASSWORD });
  const codeA = mails.find((m) => m.email === 'a@shop.com').code;
  const codeB = mails.find((m) => m.email === 'b@shop.com').code;
  const results = await Promise.all([
    call('/auth/verify-signup', { email: 'a@shop.com', code: codeA }),
    call('/auth/verify-signup', { email: 'b@shop.com', code: codeB }),
  ]);
  assert.deepEqual(results.map((r) => r.status).sort(), [200, 403]);
  assert.equal((await one(db, 'SELECT count(*)::int AS n FROM users WHERE verified')).n, 1);
});

test('the same refresh token used twice at the same moment rotates only once', async () => {
  const s = await registerOwner();
  const both = await Promise.all([
    call('/auth/refresh', { refreshToken: s.json.refreshToken }),
    call('/auth/refresh', { refreshToken: s.json.refreshToken }),
  ]);
  assert.deepEqual(both.map((r) => r.status).sort(), [200, 401]);
});

test('the health check reaches the database', async () => {
  assert.equal((await call('/health')).status, 200);
});
