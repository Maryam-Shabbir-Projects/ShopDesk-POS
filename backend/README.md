# ShopDesk server (Node.js + Neon Postgres)

Auth backend for the ShopDesk Flutter app: sign up with an emailed 6-digit code, sign in,
forgot password (code first, then new password), sessions that stay signed in.

Needs **Node 20 or newer** and a **Neon Postgres** database. Tables are created automatically on first start.

## 1. Create the database (Neon, free tier is enough)
1. Sign up at neon.com, create a project (pick the region closest to your server).
2. Open the project, press **Connect**, turn on **Connection pooling**, copy the connection string.
   It looks like `postgresql://user:pass@ep-xxxx-pooler.region.aws.neon.tech/neondb?sslmode=require`.
3. That whole string is your `DATABASE_URL`. Keep it secret: it contains the password.

## 2. Run it
```bash
cd shopdesk_server
npm install
cp .env.example .env        # set DATABASE_URL, JWT_SECRET, CODE_SECRET (see below)
npm start                   # http://localhost:3000
```
`/health` should answer `{"ok":true}` (it also checks the database).

## Settings (`.env`)
| Name | Meaning |
|---|---|
| `DATABASE_URL` | Neon connection string (pooled). Required. |
| `JWT_SECRET`, `CODE_SECRET` | Two different random strings, 32+ characters: `openssl rand -hex 48`. Required in production. |
| `SMTP_HOST` `SMTP_PORT` `SMTP_USER` `SMTP_PASS` `MAIL_FROM` | Your email sender. Required in production. |
| `OWNER_ONLY` | `true` (default): only one owner can ever register. `false`: anyone can. |
| `TRUST_PROXY` | `1` when behind Render / Railway / Fly / Caddy / nginx, so rate limits see the real IP. |

In production (`NODE_ENV=production`) the server refuses to start unless the database, both secrets and SMTP are set.

## Tests
```bash
npm test
```
Runs 26 tests against a **real Postgres**. With nothing set, it starts a temporary one by itself
(it cannot run as the root user). Or set `TEST_DATABASE_URL` to a **throw-away** database. The tests
empty the tables, so never point it at your real Neon database.

## API
All bodies are JSON. Errors look like `{"error":{"code":"invalid_code","message":"..."}}`.

| Call | Body | Answer |
|---|---|---|
| `POST /auth/signup` | `email, password` | `{ok:true}` and a code is emailed |
| `POST /auth/verify-signup` | `email, code` | session |
| `POST /auth/resend-signup` | `email` | `{ok:true}` |
| `POST /auth/signin` | `email, password` | session, or `email_not_verified` |
| `POST /auth/forgot` | `email` | `{ok:true}` (same whether or not the account exists) |
| `POST /auth/verify-reset` | `email, code` | `{resetToken}` |
| `POST /auth/reset-password` | `resetToken, newPassword` | session (all other phones are signed out) |
| `POST /auth/refresh` | `refreshToken` | new session (token rotates) |
| `POST /auth/signout` | `refreshToken` | 204 |
| `GET /auth/me` | `Authorization: Bearer <accessToken>` | `{user}` |
| `GET /health` | | `{ok:true}` |

A session is `{user, accessToken, refreshToken, expiresIn}`. The access token lasts 15 minutes,
the refresh token 30 days. Protect your own routes with `app.locals.requireAuth`.

## Where data is stored
In your Neon database, table `users` (email, password hash, role, verified). Also `codes`, `sessions`,
`reset_tokens`, `throttle`. See them in the Neon dashboard -> **Tables**, or **SQL Editor**:
```sql
SELECT email, role, verified, to_timestamp(created_at/1000) AS created FROM users;
```
Neon keeps point-in-time history (restore window depends on your plan), so there is no file to back up yourself.

## What the server enforces
- Passwords hashed with scrypt; codes stored only as a keyed hash (HMAC), never in plain text
- Codes: 6 digits, expire in 10 minutes, single use, 5 wrong tries then dead, counted atomically
  in the database so parallel guesses cannot get extra tries
- A new code at most every 30 seconds and 5 per hour, per email, counted for unknown emails too
- Forgot password and sign-up give the same answer whether or not the email has an account;
  wrong email and wrong password give the same answer and take the same time
- The new-password step needs a one-time token that only the correct emailed code can produce
- 8 wrong passwords lock that email for 15 minutes; per-IP limits on top
- Refresh tokens rotate; replaying an old one signs that account out everywhere
- Changing the password signs out every other device
- Two people verifying at the same moment cannot both become owner
- Re-submitting sign-up before verifying cannot swap the password a real owner chose

## Limits of this version
- Neon free projects pause after a few idle minutes, so the first request after a quiet period can take
  1 to 3 seconds. The server waits up to 15 seconds for the database.
- If a phone loses the answer to a token refresh (network drops at that exact moment), the next refresh
  looks like a replay and the owner must sign in again. Safe, slightly annoying.
