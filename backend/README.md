node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"





# ShopDesk server (Node.js)

Auth backend for the ShopDesk Flutter app: sign up with an emailed 6-digit code, sign in,
forgot password (code first, then new password), sessions that stay signed in.

Needs **Node 22.13 or newer**. No database to install: it uses a SQLite file.

## Run it
```bash
cd shopdesk_server
npm install
cp .env.example .env        # fill in secrets (see below)
npm run dev                 # http://localhost:3000
npm test                    # 20 tests
```
With no `SMTP_HOST` set (development only) the codes are **printed in this terminal**
instead of emailed, so you can test the whole flow without an email account.

Point the app at it:
```bash
flutter run --dart-define=API_URL=http://10.0.2.2:3000     # Android emulator
flutter run --dart-define=API_URL=http://localhost:3000    # iOS simulator / desktop
flutter run --dart-define=API_URL=http://192.168.1.20:3000 # real phone, your PC's LAN IP
```
Plain `http://` on Android needs `android:usesCleartextTraffic="true"` on `<application>` in
`android/app/src/debug/AndroidManifest.xml` (debug builds only). Production must be `https://`.

## Settings (`.env`)
| Name | Meaning |
|---|---|
| `JWT_SECRET`, `CODE_SECRET` | Two different random strings, 32+ characters. Required in production. `node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"` |
| `SMTP_HOST` `SMTP_PORT` `SMTP_USER` `SMTP_PASS` `MAIL_FROM` | Your email sender. Required in production. Resend, Postmark, SES, Mailgun, or Gmail with an app password all work. |
| `OWNER_ONLY` | `true` (default): only one owner can ever register, like the app. `false`: anyone can. |
| `TRUST_PROXY` | `1` when behind nginx / Render / Railway / Fly, so rate limits see the real IP. |
| `DB_PATH` | SQLite file. Put it on a disk that survives restarts. |

In production (`NODE_ENV=production`) the server refuses to start without the secrets and SMTP.

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

A session is `{user, accessToken, refreshToken, expiresIn}`. The access token lasts 15 minutes,
the refresh token 30 days. Protect your own routes with `app.locals.requireAuth`.

## What the server enforces
- Passwords hashed with scrypt; codes stored only as a keyed hash (HMAC), never in plain text
- Codes: 6 digits, expire in 10 minutes, single use, 5 wrong tries then dead
- A new code at most every 30 seconds and 5 per hour, per email. Counted for unknown emails too,
  so rate limits do not reveal which accounts exist
- Forgot password and sign-up give the same answer whether or not the email has an account;
  wrong email and wrong password give the same answer and take the same time
- The new-password step needs a one-time token that only the correct emailed code can produce
- 8 wrong passwords lock that email for 15 minutes; per-IP limits on top
- Refresh tokens rotate; replaying an old one signs that account out everywhere
- Changing the password signs out every other device
- Re-submitting sign-up before verifying cannot swap the password a real owner chose

## Going live checklist
1. Deploy behind HTTPS (Render, Railway, Fly.io, or a VPS with nginx + Let's Encrypt). Set `TRUST_PROXY=1`.
2. Mount a persistent disk and set `DB_PATH` to it. Back up that file.
3. Set the secrets and SMTP. Add SPF and DKIM for your sending domain or emails land in spam.
4. Build the app with `--dart-define=API_URL=https://your-server`.

## Limits of this version
- One server, one SQLite file. Fine for a shop; for many servers move to Postgres.
- If a phone loses the answer to a token refresh (network drops at that exact moment), the next
  refresh looks like a replay and the owner must sign in again. Safe, slightly annoying.
