import nodemailer from 'nodemailer';
import crypto from 'crypto';

const EMAIL_FROM = process.env.EMAIL_FROM || 'noreply@triplanai.com';
const EMAIL_HOST = process.env.EMAIL_HOST || 'smtp.gmail.com';
const EMAIL_PORT = parseInt(process.env.EMAIL_PORT || '587');
const EMAIL_USER = process.env.EMAIL_USER;
const EMAIL_PASSWORD = process.env.EMAIL_PASSWORD;
const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:4500';
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
    const verificationUrl = `${BACKEND_URL}/auth/verify-email.html?token=${token}`;

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
            body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif; line-height: 1.6; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px 20px; text-align: center; border-radius: 10px 10px 0 0; }
            .content { background: #f8f9fa; padding: 30px 20px; border-radius: 0 0 10px 10px; }
            .button { display: inline-block; padding: 12px 30px; background: #667eea; color: white; text-decoration: none; border-radius: 5px; margin: 20px 0; }
            .footer { text-align: center; margin-top: 20px; color: #666; font-size: 12px; }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <h1>Welcome to ${APP_NAME}!</h1>
            </div>
            <div class="content">
              <p>Hi ${userName},</p>
              <p>Thank you for signing up! Please verify your email address to activate your account and start planning your adventures.</p>
              <p style="text-align: center;">
                <a href="${verificationUrl}" class="button">Verify Email Address</a>
              </p>
              <p>Or copy and paste this link into your browser:</p>
              <p style="word-break: break-all; color: #667eea;">${verificationUrl}</p>
              <p><strong>This link will expire in 24 hours.</strong></p>
              <p>If you didn't create an account, you can safely ignore this email.</p>
            </div>
            <div class="footer">
              <p>&copy; 2026 ${APP_NAME}. All rights reserved.</p>
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
    const resetUrl = `${BACKEND_URL}/auth/reset-password.html?token=${token}`;

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
            body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif; line-height: 1.6; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px 20px; text-align: center; border-radius: 10px 10px 0 0; }
            .content { background: #f8f9fa; padding: 30px 20px; border-radius: 0 0 10px 10px; }
            .button { display: inline-block; padding: 12px 30px; background: #667eea; color: white; text-decoration: none; border-radius: 5px; margin: 20px 0; }
            .warning { background: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin: 20px 0; }
            .footer { text-align: center; margin-top: 20px; color: #666; font-size: 12px; }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <h1>Password Reset Request</h1>
            </div>
            <div class="content">
              <p>Hi ${userName},</p>
              <p>We received a request to reset your password. Click the button below to create a new password:</p>
              <p style="text-align: center;">
                <a href="${resetUrl}" class="button">Reset Password</a>
              </p>
              <p>Or copy and paste this link into your browser:</p>
              <p style="word-break: break-all; color: #667eea;">${resetUrl}</p>
              <div class="warning">
                <strong>⚠️ Security Notice:</strong>
                <ul>
                  <li>This link will expire in 1 hour</li>
                  <li>If you didn't request a password reset, please ignore this email</li>
                  <li>Your password won't change until you create a new one</li>
                </ul>
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
