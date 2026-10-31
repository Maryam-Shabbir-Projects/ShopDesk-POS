import nodemailer from 'nodemailer';

const SUBJECTS = {
  signup: 'Your ShopDesk verification code',
  reset: 'Your ShopDesk password reset code',
};

const INTRO = {
  signup: 'Use this code to confirm your email and finish creating your ShopDesk account.',
  reset: 'Use this code to reset your ShopDesk password.',
};

/**
 * Returns { sendCode(email, purpose, code, minutes) }.
 * With no SMTP_HOST (development only) the code is printed to the server log instead.
 */
export function createMailer(config) {
  if (!config.smtp.host) {
    return {
      async sendCode(email, purpose, code) {
        console.log(`[dev mail] ${purpose} code for ${email}: ${code}`);
      },
    };
  }
  const transport = nodemailer.createTransport({
    host: config.smtp.host,
    port: config.smtp.port,
    secure: config.smtp.port === 465,
    auth: config.smtp.user ? { user: config.smtp.user, pass: config.smtp.pass } : undefined,
  });
  return {
    async sendCode(email, purpose, code) {
      const minutes = Math.round(config.codeLifetimeMs / 60000);
      await transport.sendMail({
        from: config.smtp.from,
        to: email,
        subject: SUBJECTS[purpose],
        text: `${INTRO[purpose]}\n\nYour code: ${code}\n\nIt expires in ${minutes} minutes. If you did not ask for it, ignore this email.`,
        html: `<div style="font-family:Arial,sans-serif;max-width:420px">
  <h2 style="margin:0 0 8px">ShopDesk</h2>
  <p>${INTRO[purpose]}</p>
  <p style="font-size:32px;letter-spacing:8px;font-weight:bold;margin:20px 0">${code}</p>
  <p style="color:#555">It expires in ${minutes} minutes. If you did not ask for it, you can ignore this email.</p>
</div>`,
      });
    },
  };
}
