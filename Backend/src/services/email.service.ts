import nodemailer from 'nodemailer';
import crypto from 'crypto';

const EMAIL_FROM = process.env.EMAIL_FROM || 'noreply@triplanai.com';
const EMAIL_HOST = process.env.EMAIL_HOST || 'smtp.gmail.com';
const EMAIL_PORT = parseInt(process.env.EMAIL_PORT || '587');
const EMAIL_USER = process.env.EMAIL_USER;
const EMAIL_PASSWORD = process.env.EMAIL_PASSWORD;
const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:4500';
// Remove /api do BACKEND_URL para links de páginas HTML estáticas
const BASE_URL = BACKEND_URL.replace('/api', '');
const APP_NAME = 'TriplanAI';

// Create transporter
const transporter = nodemailer.createTransport({
  host: EMAIL_HOST,
  port: EMAIL_PORT,
  secure: EMAIL_PORT === 465,
  auth: {
    user: EMAIL_USER,
    pass: EMAIL_PASSWORD,
  },
});

// Verify transporter configuration
transporter.verify((error: Error | null, success: boolean) => {
  if (error) {
    console.error('Email service error:', error);
  } else {
    console.log('Email service ready');
  }
});

export class EmailService {
  /**
   * Generate a secure random token
   */
  static generateToken(): string {
    return crypto.randomBytes(32).toString('hex');
  }

  /**
   * Send email verification email
   */
  static async sendVerificationEmail(email: string, token: string, userName: string): Promise<void> {
    const verificationUrl = `${BASE_URL}/auth/verify-email.html?token=${token}`;

    const mailOptions = {
      from: `"${APP_NAME}" <${EMAIL_FROM}>`,
      to: email,
      subject: `Verify your ${APP_NAME} account`,
      html: `
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif; line-height: 1.6; color: #333; background: #f5f5f5; margin: 0; padding: 0; }
            .container { max-width: 600px; margin: 40px auto; padding: 0; }
            .header { background: linear-gradient(135deg, #7ED9C8 0%, #2B7A6E 100%); color: white; padding: 40px 20px; text-align: center; border-radius: 12px 12px 0 0; }
            .logo { width: 60px; height: 60px; background: rgba(255,255,255,0.2); border-radius: 15px; display: inline-flex; align-items: center; justify-content: center; margin-bottom: 16px; }
            .content { background: white; padding: 40px 30px; border-radius: 0 0 12px 12px; box-shadow: 0 4px 12px rgba(0,0,0,0.1); }
            .button { display: inline-block; padding: 14px 36px; background: #7ED9C8; color: white; text-decoration: none; border-radius: 8px; margin: 24px 0; font-weight: 600; font-size: 16px; }
            .button:hover { background: #2B7A6E; }
            .footer { text-align: center; margin-top: 24px; color: #666; font-size: 12px; padding: 20px; }
            .link-box { background: #f8f9fa; padding: 16px; border-radius: 8px; word-break: break-all; color: #2B7A6E; margin: 16px 0; border: 1px solid #e0e0e0; }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <div class="logo">
                <!-- Descomentar para usar logo personalizado -->
                <img src="https://github.com/BernardoMeneses/TriplanAI/blob/main/Backend/public/triplan_ai_logo.png?raw=true" alt="TriplanAI">
                ✈️
              </div>
              <h1 style="margin: 0; font-size: 28px;">Welcome to ${APP_NAME}!</h1>
            </div>
            <div class="content">
              <p style="font-size: 16px; margin-bottom: 8px;"><strong>Hi ${userName},</strong></p>
              <p>Thanks for creating an account. Please verify your email to activate your account and get started.</p>
              <p style="text-align: center;">
                <a href="${verificationUrl}" class="button">Verify Email</a>
              </p>
              <p style="color: #666; font-size: 14px;">Or copy and paste this link into your browser:</p>
              <div class="link-box">${verificationUrl}</div>
              <p style="background: #fff3cd; border-left: 4px solid #ffc107; padding: 12px; border-radius: 4px; font-size: 14px;">
                <strong>⏱️ This link will expire in 24 hours.</strong>
              </p>
              <p style="color: #666; font-size: 14px;">If you did not create an account, you can safely ignore this email.</p>
            </div>
            <div class="footer">
              <p style="margin: 0;">&copy; 2026 ${APP_NAME}. All rights reserved.</p>
              <p style="margin: 8px 0 0 0; color: #999;">AI-powered trip planning</p>
            </div>
          </div>
        </body>
        </html>
      `,
      text: `
        Welcome to ${APP_NAME}!

        Hi ${userName},

        Thanks for creating an account. Please verify your email address by clicking the link below:

        ${verificationUrl}

        This link will expire in 24 hours.

        If you did not create an account, you can safely ignore this email.

        © 2026 ${APP_NAME}. All rights reserved.
      `,
    };

    await transporter.sendMail(mailOptions);
  }

  /**
   * Send password reset email
   */
  static async sendPasswordResetEmail(email: string, token: string, userName: string): Promise<void> {
    const resetUrl = `${BASE_URL}/auth/reset-password.html?token=${token}`;

    const mailOptions = {
      from: `"${APP_NAME}" <${EMAIL_FROM}>`,
      to: email,
      subject: `Reset your ${APP_NAME} password`,
      html: `
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif; line-height: 1.6; color: #333; background: #f5f5f5; margin: 0; padding: 0; }
            .container { max-width: 600px; margin: 40px auto; padding: 0; }
            .header { background: linear-gradient(135deg, #7ED9C8 0%, #2B7A6E 100%); color: white; padding: 40px 20px; text-align: center; border-radius: 12px 12px 0 0; }
            .logo { width: 60px; height: 60px; background: rgba(255,255,255,0.2); border-radius: 15px; display: inline-flex; align-items: center; justify-content: center; margin-bottom: 16px; }
            .logo img { width: 48px; height: 48px; object-fit: contain; }
            .content { background: white; padding: 40px 30px; border-radius: 0 0 12px 12px; box-shadow: 0 4px 12px rgba(0,0,0,0.1); }
            .button { display: inline-block; padding: 14px 36px; background: #7ED9C8; color: white !important; text-decoration: none; border-radius: 8px; margin: 24px 0; font-weight: 600; font-size: 16px; }
            .button:hover { background: #2B7A6E; }
            .warning { background: #fff3cd; border-left: 4px solid #ffc107; padding: 16px; margin: 20px 0; border-radius: 4px; }
            .link-box { background: #f8f9fa; padding: 16px; border-radius: 8px; word-break: break-all; color: #2B7A6E; margin: 16px 0; border: 1px solid #e0e0e0; }
            .footer { text-align: center; margin-top: 24px; color: #666; font-size: 12px; padding: 20px; }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <div class="logo">
                <img src="https://github.com/BernardoMeneses/TriplanAI/blob/main/Backend/public/triplan_ai_logo.png?raw=true" alt="TriplanAI">
              </div>
              <h1 style="margin: 0; font-size: 28px;">Reset your password</h1>
            </div>
            <div class="content">
              <p style="font-size: 16px; margin-bottom: 8px;"><strong>Hi ${userName},</strong></p>
              <p>We received a request to reset your password. Click the button below to create a new password:</p>
              <p style="text-align: center;">
                <a href="${resetUrl}" class="button">Reset Password</a>
              </p>
              <p style="color: #666; font-size: 14px;">Or copy and paste this link into your browser:</p>
              <div class="link-box">${resetUrl}</div>
              <div class="warning">
                <strong>⚠️ Security Notice:</strong>
                <ul style="margin: 8px 0; padding-left: 20px;">
                  <li>This link will expire in 1 hour</li>
                  <li>If you didn't request a password reset, ignore this email</li>
                  <li>Your password will not change until you create a new one</li>
                </ul>
              </div>
            </div>
            <div class="footer">
              <p style="margin: 0;">&copy; 2026 ${APP_NAME}. All rights reserved.</p>
              <p style="margin: 8px 0 0 0; color: #999;">AI-powered trip planning</p>
            </div>
            <div class="footer">
              <p>&copy; 2026 ${APP_NAME}. All rights reserved.</p>
            </div>
          </div>
        </body>
        </html>
      `,
      text: `
        Password Reset Request

        Hi ${userName},

        We received a request to reset your password. Click the link below to create a new password:

        ${resetUrl}

        This link will expire in 1 hour.

        If you didn't request a password reset, please ignore this email. Your password won't change until you create a new one.

        © 2026 ${APP_NAME}. All rights reserved.
      `,
    };

    await transporter.sendMail(mailOptions);
  }

  /**
   * Send welcome email after verification
   */
  static async sendWelcomeEmail(email: string, userName: string): Promise<void> {
    const mailOptions = {
      from: `"${APP_NAME}" <${EMAIL_FROM}>`,
      to: email,
      subject: `Welcome to ${APP_NAME}! 🎉`,
      html: `
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif; line-height: 1.6; color: #333; background: #f5f5f5; margin: 0; padding: 0; }
            .container { max-width: 600px; margin: 40px auto; padding: 0; }
            .header { background: linear-gradient(135deg, #7ED9C8 0%, #2B7A6E 100%); color: white; padding: 40px 20px; text-align: center; border-radius: 12px 12px 0 0; }
            .logo { width: 60px; height: 60px; background: rgba(255,255,255,0.2); border-radius: 15px; display: inline-flex; align-items: center; justify-content: center; margin-bottom: 16px; font-size: 32px; }
            .logo img { width: 48px; height: 48px; object-fit: contain; }
            .content { background: white; padding: 40px 30px; border-radius: 0 0 12px 12px; box-shadow: 0 4px 12px rgba(0,0,0,0.1); }
            .feature { margin: 20px 0; padding: 20px; background: #f8f9fa; border-radius: 8px; border-left: 4px solid #7ED9C8; }
            .feature strong { color: #2B7A6E; display: block; margin-bottom: 8px; font-size: 16px; }
            .button { display: inline-block; padding: 14px 36px; background: #7ED9C8; color: white !important; text-decoration: none; border-radius: 8px; margin: 24px 0; font-weight: 600; font-size: 16px; }
            .footer { text-align: center; margin-top: 24px; color: #666; font-size: 12px; padding: 20px; }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <div class="logo">
                <img src="https://github.com/BernardoMeneses/TriplanAI/blob/main/Backend/public/triplan_ai_logo.png?raw=true" alt="TriplanAI">
              </div>
              <h1 style="margin: 0; font-size: 28px;">Account Activated!</h1>
            </div>
            <div class="content">
              <p style="font-size: 16px; margin-bottom: 8px;"><strong>Hi ${userName},</strong></p>
              <p>Your email has been successfully verified. Welcome to the ${APP_NAME} community.</p>
              <p><strong>What you can do next:</strong></p>
              <div class="feature">
                <strong>✈️ Planeia as Tuas Viagens</strong>
                <p>Cria itinerários detalhados para as tuas próximas aventuras</p>
              </div>
              <div class="feature">
                <strong>🗺️ Descobre Lugares</strong>
                <p>Encontra destinos incríveis, restaurantes e atrações</p>
              </div>
              <div class="feature">
                <strong>🤖 Assistência IA</strong>
                <p>Obtém recomendações personalizadas com inteligência artificial</p>
              </div>
              <div class="feature">
                <strong>📍 Navegação</strong>
                <p>Navegação em tempo real e planeamento de rotas</p>
              </div>
              <p style="text-align: center;">
                <a href="triplanai://app/login" class="button">Open App</a>
              </p>
              <p>Ready to get started? Open the app and create your first trip!</p>
            </div>
            <div class="footer">
              <p style="margin: 0;">&copy; 2026 ${APP_NAME}. All rights reserved.</p>
              <p style="margin: 8px 0 0 0; color: #999;">AI-powered trip planning</p>
            </div>
          </div>
        </body>
        </html>
      `,
    };

    await transporter.sendMail(mailOptions);
  }

  /**
   * Send account deletion confirmation email with a link to confirm
   */
  static async sendAccountDeletionEmail(email: string, token: string, userName: string): Promise<void> {
    const deleteUrl = `${BASE_URL}/delete-account.html?token=${token}`;

    const mailOptions = {
      from: `"${APP_NAME}" <${EMAIL_FROM}>`,
      to: email,
      subject: `Account deletion request — ${APP_NAME}`,
      html: `
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif; line-height:1.6; color:#333; background:#f5f5f5; margin:0; padding:0 }
            .container { max-width:600px; margin:40px auto; }
            .header { background: linear-gradient(135deg,#7ED9C8 0%,#2B7A6E 100%); color:#fff; padding:32px 20px; text-align:center; border-radius:12px 12px 0 0 }
            .logo { width:56px; height:56px; border-radius:12px; display:inline-block; margin-bottom:12px }
            .content { background:#fff; padding:28px 24px; border-radius:0 0 12px 12px; box-shadow:0 4px 12px rgba(0,0,0,0.08) }
            .btn { display:inline-block; padding:14px 36px; background:#d9534f; color:#fff; text-decoration:none; border-radius:10px; font-weight:600 }
            .link-box { background:#f8f9fa; padding:14px; border-radius:8px; word-break:break-all; color:#d9534f; margin:12px 0; border:1px solid #eaeaea }
            .muted { color:#666; font-size:14px }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <img class="logo" src="https://github.com/BernardoMeneses/TriplanAI/blob/main/Backend/public/triplan_ai_logo.png?raw=true" alt="${APP_NAME}" />
              <h1 style="margin:8px 0 0 0; font-size:20px">Account deletion request</h1>
            </div>
            <div class="content">
              <p style="font-size:15px"><strong>Hi ${userName || ''},</strong></p>
              <p class="muted">We received a request to delete your account. If you want to proceed, please confirm by clicking the button below. This action is permanent and will remove your account and related data.</p>
              <p style="text-align:center; margin-top:18px">
                <a class="btn" href="${deleteUrl}">Confirm account deletion</a>
              </p>
              <p class="muted" style="margin-top:12px">Or copy and paste this link into your browser:</p>
              <div class="link-box">${deleteUrl}</div>
              <p class="muted" style="font-size:13px; margin-top:8px">This link will expire in 24 hours.</p>
              <p class="muted" style="font-size:13px; margin-top:8px">After confirmation the page will redirect you back to the app. The app uses this deep link to clear local data and show the login screen.</p>
            </div>
            <div style="text-align:center; color:#999; font-size:12px; padding:16px">© 2026 ${APP_NAME} — Planeamento de viagens com IA</div>
          </div>
        </body>
        </html>
      `,
      text: `Pedido de eliminação de conta\n\nOlá ${userName || ''},\n\nPara confirmar a eliminação da tua conta, acede ao link: ${deleteUrl}\n\nEste link expira em 24 horas.`,
    };

    await transporter.sendMail(mailOptions);
  }

  static async sendAccountDeletedNotification(email: string, userName?: string): Promise<void> {
    const mailOptions = {
      from: `"${APP_NAME}" <${EMAIL_FROM}>`,
      to: email,
      subject: `Conta removida — ${APP_NAME}`,
      html: `
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width,initial-scale=1">
          <style>
            body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Ubuntu,Arial,sans-serif;background:#f5f5f5;margin:0;padding:0}
            .box{max-width:600px;margin:40px auto;background:#fff;border-radius:12px;overflow:hidden;box-shadow:0 8px 30px rgba(0,0,0,0.08)}
            .content{padding:28px}
            .muted{color:#666}
            .footer{padding:16px;text-align:center;color:#999;font-size:12px}
          </style>
        </head>
        <body>
          <div class="box">
            <div style="background:linear-gradient(135deg,#7ED9C8 0%,#2B7A6E 100%);padding:20px;text-align:center;color:#fff"><h2 style="margin:0">Conta Removida</h2></div>
            <div class="content">
              <p><strong>Olá ${userName || ''},</strong></p>
              <p class="muted">A tua conta foi removida conforme o pedido. Todos os dados associados foram apagados.</p>
              <p class="muted">Se foi um engano, podes criar uma nova conta a qualquer momento.</p>
            </div>
            <div class="footer">© 2026 ${APP_NAME}</div>
          </div>
        </body>
        </html>
      `,
      text: `A tua conta foi removida. Se foi um engano, cria uma nova conta.`,
    };

    await transporter.sendMail(mailOptions);
  }
}
