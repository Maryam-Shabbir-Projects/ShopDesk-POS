const env = process.env;

const num = (v, d) => (v !== undefined && v !== '' && !Number.isNaN(Number(v)) ? Number(v) : d);
const bool = (v, d) => (v === undefined || v === '' ? d : ['1', 'true', 'yes'].includes(String(v).toLowerCase()));

export function loadConfig(overrides = {}) {
  const config = {
    nodeEnv: env.NODE_ENV ?? 'development',
    port: num(env.PORT, 3000),
    databaseUrl: env.DATABASE_URL ?? '',
    jwtSecret: env.JWT_SECRET ?? '',
    codeSecret: env.CODE_SECRET ?? '',
    ownerOnly: bool(env.OWNER_ONLY, true),
    trustProxy: num(env.TRUST_PROXY, 0),
    smtp: {
      host: env.SMTP_HOST ?? '',
      port: num(env.SMTP_PORT, 587),
      user: env.SMTP_USER ?? '',
      pass: env.SMTP_PASS ?? '',
      from: env.MAIL_FROM ?? 'ShopDesk <no-reply@localhost>',
    },
    // Rules. Same numbers the Flutter demo uses.
    codeLifetimeMs: 10 * 60 * 1000,
    codeMaxAttempts: 5,
    resendCooldownMs: 30 * 1000,
    maxCodesPerHour: 5,
    accessTokenSeconds: 15 * 60,
    refreshTokenDays: 30,
    resetTokenMs: 10 * 60 * 1000,
    maxSignInFailures: 8, // per email, per 15 minutes
    ipRateLimit: true, // per-IP limits on top of the per-email ones
    ...overrides,
  };

  if (config.nodeEnv === 'production') {
    const problems = [];
    if (config.jwtSecret.length < 32) problems.push('JWT_SECRET must be at least 32 characters');
    if (config.codeSecret.length < 32) problems.push('CODE_SECRET must be at least 32 characters');
    if (!config.databaseUrl) problems.push('DATABASE_URL is required (your Neon connection string)');
    if (!config.smtp.host) problems.push('SMTP_HOST is required so codes can be emailed');
    if (problems.length) throw new Error('Bad configuration:\n - ' + problems.join('\n - '));
  } else {
    // Dev convenience only. Tokens do not survive a restart without real secrets.
    config.jwtSecret ||= 'dev-only-jwt-secret-change-me-0123456789abcdef';
    config.codeSecret ||= 'dev-only-code-secret-change-me-0123456789abcdef';
  }
  return config;
}
