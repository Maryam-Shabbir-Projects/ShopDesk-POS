# Deploying ShopDesk server

Target: one small Linux VPS (1 GB RAM is plenty), Docker, automatic HTTPS, and a Neon Postgres database. About 30 minutes.
Any provider works (DigitalOcean, Hetzner, Linode, AWS Lightsail, Vultr). Ubuntu 24.04.

## 1. Before you start
1. **A domain** you control, for example `yourshop.com`. The API will live at `api.yourshop.com`.
2. **A transactional email service** with your domain verified: Resend, Postmark, Amazon SES or Mailgun.
   Add the SPF and DKIM records it gives you. Without them the codes land in spam.
   Copy its SMTP host, username and password.
3. **A VPS.** Note its public IP.
4. **A Neon database.** Follow step 1 in `README.md` and keep the pooled connection string (`DATABASE_URL`).
5. In your domain's DNS add an **A record**: `api` -> the VPS IP. Wait until it resolves.

## 2. Prepare the server
```bash
ssh root@YOUR_IP
apt update && apt -y upgrade
curl -fsSL https://get.docker.com | sh
ufw allow OpenSSH && ufw allow 80 && ufw allow 443 && ufw --force enable
```
(Better: create a non-root user, add it to the `docker` group, and disable password SSH login.)

## 3. Put the code on the server
From your computer, copy the `shopdesk_server` folder (not `node_modules`):
```bash
scp -r shopdesk_server root@YOUR_IP:/opt/shopdesk
```

## 4. Configure
```bash
cd /opt/shopdesk
cp .env.production.example .env
nano .env        # fill in every empty value
```
Paste the Neon string into `DATABASE_URL`. Make the two secrets with `openssl rand -hex 48` (run it twice,
different values). Use the SMTP details from your email service and set `API_DOMAIN`.

## 5. Start
```bash
docker compose up -d --build
docker compose logs -f api     # expect: "ShopDesk auth server on :3000 (production, ownerOnly=true, db=postgres)"
curl https://api.yourshop.com/health     # {"ok":true}
```
Caddy fetches the HTTPS certificate on its own the first time (needs ports 80 and 443 open and DNS ready).
The server refuses to start in production if a secret or SMTP is missing, and says which.

## 6. Build the app against it
```bash
flutter build apk --release --dart-define=API_URL=https://api.yourshop.com
flutter build appbundle --release --dart-define=API_URL=https://api.yourshop.com   # Play Store
flutter build ios --release --dart-define=API_URL=https://api.yourshop.com
```
The app no longer adds sample data, so every shop starts empty. A phone that already ran an older
test build still holds the old sample products: uninstall the app (or clear its storage) once before release.

## 7. Create the owner
Open the released app, tap Create owner account, enter the emailed code. The first verified account
becomes the owner and sign-up closes for everyone else.

## Running it
| Task | Command |
|---|---|
| Logs | `docker compose logs -f api` |
| Update after code changes | copy the new files, then `docker compose up -d --build` |
| Restart | `docker compose restart api` |

**Database and backups.** All data is in Neon, not on this server, so rebuilding the server loses nothing.
In the Neon console check your plan's restore window (point-in-time restore) and, if you want, export a
`pg_dump` now and then: `pg_dump "$DATABASE_URL" > backup.sql`.

**Lost the owner password and email?** Reset needs email access. If the email address itself is lost, delete the
user row in the Neon SQL Editor (`DELETE FROM users;`) and register again.

## Other hosts
- **Render / Railway / Fly.io:** use the `Dockerfile`. Set the variables from `.env.production.example`
  (skip `API_DOMAIN`) and `TRUST_PROXY=1`. No disk is needed because the data is in Neon.
  Health check path: `/health`. Several instances are fine.

## Production checklist
- [ ] DNS A record resolves, `https://api.../health` works with a valid certificate
- [ ] `JWT_SECRET` and `CODE_SECRET` are different 96-character random values
- [ ] Test email arrives in the **inbox**, not spam (send a code to Gmail and Outlook addresses)
- [ ] App built with the `https://` `API_URL`, installed fresh (no old test data on the phone)
- [ ] Owner account created; confirm a second sign-up attempt shows "turned off"
- [ ] Neon restore window checked (or a `pg_dump` saved)
- [ ] `DATABASE_URL` is the **pooled** string and is only in `.env` on the server
- [ ] Only ports 22, 80, 443 open
