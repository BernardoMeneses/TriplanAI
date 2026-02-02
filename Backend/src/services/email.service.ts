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
              <h1 style="margin: 0; font-size: 28px;">Bem-vindo ao ${APP_NAME}!</h1>
            </div>
            <div class="content">
              <p style="font-size: 16px; margin-bottom: 8px;"><strong>Olá ${userName},</strong></p>
              <p>Obrigado por te registares! Verifica o teu email para ativares a conta e começares a planear as tuas aventuras.</p>
              <p style="text-align: center;">
                <a href="${verificationUrl}" class="button">Verificar Email</a>
              </p>
              <p style="color: #666; font-size: 14px;">Ou copia e cola este link no navegador:</p>
              <div class="link-box">${verificationUrl}</div>
              <p style="background: #fff3cd; border-left: 4px solid #ffc107; padding: 12px; border-radius: 4px; font-size: 14px;">
                <strong>⏱️ Este link expira em 24 horas.</strong>
              </p>
              <p style="color: #666; font-size: 14px;">Se não criaste uma conta, podes ignorar este email.</p>
            </div>
            <div class="footer">
              <p style="margin: 0;">&copy; 2026 ${APP_NAME}. Todos os direitos reservados.</p>
              <p style="margin: 8px 0 0 0; color: #999;">Planeamento de viagens com IA</p>
            </div>
          </div>
        </body>
        </html>
      `,
      text: `
        Welcome to ${APP_NAME}!
        
        Hi ${userName},
        
        Thank you for signing up! Please verify your email address by clicking the link below:
        
        ${verificationUrl}
        
        This link will expire in 24 hours.
        
        If you didn't create an account, you can safely ignore this email.
        
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
            .content { background: white; padding: 40px 30px; border-radius: 0 0 12px 12px; box-shadow: 0 4px 12px rgba(0,0,0,0.1); }
            .button { display: inline-block; padding: 14px 36px; background: #7ED9C8; color: white; text-decoration: none; border-radius: 8px; margin: 24px 0; font-weight: 600; font-size: 16px; }
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
                <!-- Descomentar para usar logo personalizado -->
                <!-- <img src="https://seu-dominio.com/images/logo-white.png" alt="TriplanAI"> -->
                🔒
              </div>
              <h1 style="margin: 0; font-size: 28px;">Redefinir Password</h1>
            </div>
            <div class="content">
              <p style="font-size: 16px; margin-bottom: 8px;"><strong>Olá ${userName},</strong></p>
              <p>Recebemos um pedido para redefinir a tua password. Clica no botão abaixo para criar uma nova
            <div class="content">definir Password</a>
              </p>
              <p style="color: #666; font-size: 14px;">Ou copia e cola este link no navegador:</p>
              <div class="link-box">${resetUrl}</div>
              <div class="warning">
                <strong>⚠️ Aviso de Segurança:</strong>
                <ul style="margin: 8px 0; padding-left: 20px;">
                  <li>Este link expira em 1 hora</li>
                  <li>Se não pediste para redefinir a password, ignora este email</li>
                  <li>A tua password não mudará até criares uma nova</li>
                </ul>
              </div>
            </div>
            <div class="footer">
              <p style="margin: 0;">&copy; 2026 ${APP_NAME}. Todos os direitos reservados.</p>
              <p style="margin: 8px 0 0 0; color: #999;">Planeamento de viagens com IA
              </div>
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
            body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif; line-height: 1.6; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px 20px; text-align: center; border-radius: 10px 10px 0 0; }
            .content { background: #f8f9fa; padding: 30px 20px; border-radius: 0 0 10px 10px; }
            .feature { margin: 15px 0; padding: 15px; background: white; border-radius: 5px; }
            .footer { text-align: center; margin-top: 20px; color: #666; font-size: 12px; }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <h1>🎉 You're All Set!</h1>
            </div>
            <div class="content">
              <p>Hi ${userName},</p>
              <p>Your email has been verified successfully! Welcome to the ${APP_NAME} community.</p>
              <p><strong>Here's what you can do now:</strong></p>
              <div class="feature">
                <strong>✈️ Plan Your Trips</strong>
                <p>Create detailed itineraries for your upcoming adventures</p>
              </div>
              <div class="feature">
                <strong>🗺️ Discover Places</strong>
                <p>Find amazing destinations, restaurants, and attractions</p>
              </div>
              <div class="feature">
                <strong>🤖 AI Assistance</strong>
                <p>Get personalized recommendations powered by AI</p>
              </div>
              <div class="feature">
                <strong>📍 Navigate</strong>
                <p>Real-time navigation and route planning</p>
              </div>
              <p>Ready to start planning? Open the app and create your first trip!</p>
            </div>
            <div class="footer">
              <p>&copy; 2026 ${APP_NAME}. All rights reserved.</p>
            </div>
          </div>
        </body>
        </html>
      `,
    };

    await transporter.sendMail(mailOptions);
  }
}
