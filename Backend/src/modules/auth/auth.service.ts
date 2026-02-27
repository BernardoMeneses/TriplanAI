import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import { query } from '../../config/database';
import { EmailService } from '../../services/email.service';

const JWT_SECRET = process.env.JWT_SECRET || 'triplanai-secret-key-change-in-production';
const JWT_EXPIRES_IN = '365d'; // Token válido por 1 ano para testes
const SALT_ROUNDS = 10;

export interface User {
  id: string;
  email: string;
  username: string;
  password_hash?: string; // Optional for OAuth users
  full_name: string;
  phone?: string;
  profile_picture_url?: string;
  preferences?: Record<string, any>;
  auth_provider: string; // native, google, etc
  email_verified: boolean;
  email_verification_token?: string;
  email_verification_token_expires?: Date;
  password_reset_token?: string;
  password_reset_token_expires?: Date;
  google_id?: string;
  google_access_token?: string;
  google_refresh_token?: string;
  created_at: Date;
  updated_at: Date;
  last_login?: Date;
  is_active: boolean;
}

export class AuthService {
  async register(
    email: string,
    password: string,
    fullName: string,
    username: string,
    phone?: string
  ): Promise<{ user: Omit<User, 'password_hash'>; token: string; message: string }> {
    // Check if user already exists (both native and OAuth)
    const existingUser = await query(
      'SELECT id, auth_provider, email FROM users WHERE email = $1 OR username = $2',
      [email, username]
    );
    
    if (existingUser.rows.length > 0) {
      const existing = existingUser.rows[0];
      
      // Se o email é o que já existe (não é só username)
      if (existing.email === email) {
        if (existing.auth_provider === 'native') {
          throw new Error('EMAIL_EXISTS_NATIVE|Este email já está registado. Faz login com email e password.');
        } else {
          throw new Error(`EMAIL_EXISTS_${existing.auth_provider.toUpperCase()}|Este email já está associado a uma conta ${existing.auth_provider === 'google' ? 'Google' : existing.auth_provider}. Usa "Sign in via Google" para entrar.`);
        }
      } else {
        throw new Error('USERNAME_EXISTS|Este username já está em uso.');
      }
    }

    // Hash password
    const passwordHash = await bcrypt.hash(password, SALT_ROUNDS);

    // Generate email verification token
    const verificationToken = EmailService.generateToken();
    const tokenExpires = new Date(Date.now() + 24 * 60 * 60 * 1000); // 24 hours

    // Create user
    const result = await query<User>(
      `INSERT INTO users (
        email, username, password_hash, full_name, phone, 
        auth_provider, email_verified, email_verification_token, email_verification_token_expires
      )
       VALUES ($1, $2, $3, $4, $5, 'native', false, $6, $7)
       RETURNING id, email, username, full_name, phone, profile_picture_url, preferences, 
                 auth_provider, email_verified, created_at, updated_at, is_active`,
      [email, username, passwordHash, fullName, phone || null, verificationToken, tokenExpires]
    );

    const user = result.rows[0];

    // Send verification email
    try {
      await EmailService.sendVerificationEmail(email, verificationToken, fullName);
    } catch (error) {
      console.error('Failed to send verification email:', error);
      // Don't fail registration if email fails
    }

    // Generate token (but login will require verification)
    const token = this.generateToken(user.id);

    return { 
      user, 
      token,
      message: 'Account created! Please check your email to verify your account.' 
    };
  }

  async login(identifier: string, password: string): Promise<{ user: Omit<User, 'password_hash'>; token: string }> {
    // Find user by email or username (only native auth)
    const result = await query<User>(
      'SELECT * FROM users WHERE (email = $1 OR username = $1) AND auth_provider = $2 AND is_active = true',
      [identifier, 'native']
    );
    
    if (result.rows.length === 0) {
      throw new Error('Credenciais inválidas');
    }

    const user = result.rows[0];

    // Verify password
    if (!user.password_hash) {
      throw new Error('Esta conta usa login social');
    }
    
    const isValidPassword = await bcrypt.compare(password, user.password_hash);
    if (!isValidPassword) {
      throw new Error('Credenciais inválidas');
    }

    // Check email verification
    if (!user.email_verified) {
      throw new Error('Por favor, verifique o seu email antes de fazer login');
    }

    // Update last login
    await query('UPDATE users SET last_login = CURRENT_TIMESTAMP WHERE id = $1', [user.id]);

    // Generate token
    const token = this.generateToken(user.id);

    // Remove password_hash from response
    const { password_hash, ...userWithoutPassword } = user;

    return { user: userWithoutPassword, token };
  }

  async validateToken(token: string): Promise<{ valid: boolean; userId?: string }> {
    try {
      const decoded = jwt.verify(token, JWT_SECRET) as { userId: string };
      
      // Check if user still exists and is active
      const result = await query('SELECT id FROM users WHERE id = $1 AND is_active = true', [decoded.userId]);
      
      if (result.rows.length === 0) {
        return { valid: false };
      }

      return { valid: true, userId: decoded.userId };
    } catch {
      return { valid: false };
    }
  }

  async getUserById(userId: string): Promise<Omit<User, 'password_hash'> | null> {
    const result = await query<User>(
      `SELECT id, email, username, full_name, phone, profile_picture_url, preferences, 
              created_at, updated_at, last_login, is_active 
       FROM users WHERE id = $1`,
      [userId]
    );
    return result.rows[0] || null;
  }

  async updateUser(userId: string, data: Partial<User>): Promise<Omit<User, 'password_hash'> | null> {
    const fields: string[] = [];
    const values: any[] = [];
    let paramIndex = 1;

    const allowedFields = ['full_name', 'phone', 'profile_picture_url', 'preferences'];

    for (const field of allowedFields) {
      if (data[field as keyof User] !== undefined) {
        fields.push(`${field} = $${paramIndex}`);
        values.push(data[field as keyof User]);
        paramIndex++;
      }
    }

    if (fields.length === 0) {
      return this.getUserById(userId);
    }

    values.push(userId);
    const result = await query<User>(
      `UPDATE users SET ${fields.join(', ')} WHERE id = $${paramIndex} 
       RETURNING id, email, full_name, phone, profile_picture_url, preferences, created_at, updated_at, is_active`,
      values
    );
    return result.rows[0] || null;
  }

  async logout(userId: string): Promise<{ success: boolean }> {
    // For JWT-based auth, logout is handled client-side
    // Here we could implement token blacklisting if needed
    return { success: true };
  }

  async verifyEmail(token: string): Promise<{ success: boolean; message: string }> {
    // Find user by verification token
    const result = await query<User>(
      `SELECT * FROM users WHERE email_verification_token = $1 
       AND email_verification_token_expires > NOW()`,
      [token]
    );

    if (result.rows.length === 0) {
      throw new Error('Token de verificação inválido ou expirado');
    }

    const user = result.rows[0];

    // Update user as verified
    await query(
      `UPDATE users SET 
        email_verified = true, 
        email_verification_token = NULL, 
        email_verification_token_expires = NULL,
        updated_at = CURRENT_TIMESTAMP
       WHERE id = $1`,
      [user.id]
    );

    // Send welcome email
    try {
      await EmailService.sendWelcomeEmail(user.email, user.full_name);
    } catch (error) {
      console.error('Failed to send welcome email:', error);
    }

    return { success: true, message: 'Email verificado com sucesso!' };
  }

  async resendVerificationEmail(email: string): Promise<{ success: boolean; message: string }> {
    const result = await query<User>(
      'SELECT * FROM users WHERE email = $1 AND auth_provider = $2',
      [email, 'native']
    );

    if (result.rows.length === 0) {
      throw new Error('Utilizador não encontrado');
    }

    const user = result.rows[0];

    if (user.email_verified) {
      throw new Error('Email já verificado');
    }

    // Generate new verification token
    const verificationToken = EmailService.generateToken();
    const tokenExpires = new Date(Date.now() + 24 * 60 * 60 * 1000);

    await query(
      `UPDATE users SET 
        email_verification_token = $1, 
        email_verification_token_expires = $2
       WHERE id = $3`,
      [verificationToken, tokenExpires, user.id]
    );

    // Send verification email
    await EmailService.sendVerificationEmail(email, verificationToken, user.full_name);

    return { success: true, message: 'Email de verificação enviado!' };
  }

  async requestPasswordReset(email: string): Promise<{ success: boolean; message: string }> {
    const result = await query<User>(
      'SELECT * FROM users WHERE email = $1 AND auth_provider = $2',
      [email, 'native']
    );

    if (result.rows.length === 0) {
      // Don't reveal if user exists
      return { success: true, message: 'Se o email existir, receberá um link de reset' };
    }

    const user = result.rows[0];

    // Generate reset token
    const resetToken = EmailService.generateToken();
    const tokenExpires = new Date(Date.now() + 60 * 60 * 1000); // 1 hour

    await query(
      `UPDATE users SET 
        password_reset_token = $1, 
        password_reset_token_expires = $2
       WHERE id = $3`,
      [resetToken, tokenExpires, user.id]
    );

    // Send reset email
    await EmailService.sendPasswordResetEmail(email, resetToken, user.full_name);

    return { success: true, message: 'Email de reset enviado!' };
  }

  async resetPassword(token: string, newPassword: string): Promise<{ success: boolean; message: string }> {
    // Find user by reset token
    const result = await query<User>(
      `SELECT * FROM users WHERE password_reset_token = $1 
       AND password_reset_token_expires > NOW()`,
      [token]
    );

    if (result.rows.length === 0) {
      throw new Error('Token de reset inválido ou expirado');
    }

    const user = result.rows[0];

    // Hash new password
    const passwordHash = await bcrypt.hash(newPassword, SALT_ROUNDS);

    // Update password and clear reset token
    await query(
      `UPDATE users SET 
        password_hash = $1, 
        password_reset_token = NULL, 
        password_reset_token_expires = NULL,
        updated_at = CURRENT_TIMESTAMP
       WHERE id = $2`,
      [passwordHash, user.id]
    );

    return { success: true, message: 'Password redefinida com sucesso!' };
  }

  async googleLogin(googleData: {
    googleId: string;
    email: string;
    name: string;
    picture?: string;
    accessToken: string;
    refreshToken?: string;
  }): Promise<{ user: Omit<User, 'password_hash'>; token: string; isNewUser: boolean }> {
    // Check if user exists with this email but different provider
    const emailCheck = await query<User>(
      'SELECT * FROM users WHERE email = $1',
      [googleData.email]
    );

    if (emailCheck.rows.length > 0 && emailCheck.rows[0].auth_provider !== 'google') {
      throw new Error('EMAIL_EXISTS_NATIVE|Este email já está registado com Email/Password. Faz login com email e password.');
    }

    // Check if user exists with Google ID
    let result = await query<User>(
      'SELECT * FROM users WHERE google_id = $1 OR (email = $2 AND auth_provider = $3)',
      [googleData.googleId, googleData.email, 'google']
    );

    let user: User;
    let isNewUser = false;

    if (result.rows.length === 0) {
      // Create new user with Google auth
      const username = googleData.email.split('@')[0] + '_' + Math.random().toString(36).substring(7);
      
      const insertResult = await query<User>(
        `INSERT INTO users (
          email, username, full_name, profile_picture_url,
          auth_provider, email_verified, google_id, google_access_token, google_refresh_token
        )
         VALUES ($1, $2, $3, $4, 'google', true, $5, $6, $7)
         RETURNING id, email, username, full_name, phone, profile_picture_url, preferences, 
                   auth_provider, email_verified, created_at, updated_at, is_active`,
        [
          googleData.email,
          username,
          googleData.name,
          googleData.picture || null,
          googleData.googleId,
          googleData.accessToken,
          googleData.refreshToken || null,
        ]
      );

      user = insertResult.rows[0];
      isNewUser = true;

      // Send welcome email
      try {
        await EmailService.sendWelcomeEmail(user.email, user.full_name);
      } catch (error) {
        console.error('Failed to send welcome email:', error);
      }
    } else {
      user = result.rows[0];
      
      // Update Google tokens
      await query(
        `UPDATE users SET 
          google_access_token = $1, 
          google_refresh_token = COALESCE($2, google_refresh_token),
          last_login = CURRENT_TIMESTAMP,
          profile_picture_url = COALESCE($3, profile_picture_url)
         WHERE id = $4`,
        [googleData.accessToken, googleData.refreshToken, googleData.picture, user.id]
      );
    }

    // Generate JWT token
    const token = this.generateToken(user.id);

    const { password_hash, ...userWithoutPassword } = user;

    return { user: userWithoutPassword, token, isNewUser };
  }

  /**
   * Create an account deletion request and send confirmation email
   */
  async requestAccountDeletion(email: string): Promise<{ success: boolean; message: string }> {
    // Find user by email
    const result = await query<User>('SELECT * FROM users WHERE email = $1', [email]);
    if (result.rows.length === 0) {
      // Do not reveal whether user exists
      return { success: true, message: 'Se o email existir, receberás um link para confirmar a eliminação' };
    }

    const user = result.rows[0];

    // Ensure account_deletion_requests table exists (simple migration-on-demand)
    await query(`
      CREATE TABLE IF NOT EXISTS account_deletion_requests (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        email VARCHAR(255) NOT NULL,
        token VARCHAR(255) NOT NULL,
        expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      )
    `);

    const token = EmailService.generateToken();
    const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000); // 24h

    await query(
      `INSERT INTO account_deletion_requests (user_id, email, token, expires_at) VALUES ($1, $2, $3, $4)`,
      [user.id, email, token, expiresAt]
    );

    // Send email with confirmation link
    try {
      await EmailService.sendAccountDeletionEmail(email, token, user.full_name);
    } catch (e) {
      console.error('Failed to send account deletion email:', e);
    }

    return { success: true, message: 'Se o email existir, receberás um link para confirmar a eliminação' };
  }

  /**
   * Confirm account deletion using token and remove the user
   */
  async confirmAccountDeletion(token: string): Promise<{ success: boolean; message: string }> {
    // Find request
    const result = await query(`SELECT * FROM account_deletion_requests WHERE token = $1 AND expires_at > NOW()`, [token]);
    if (result.rows.length === 0) {
      throw new Error('Token inválido ou expirado');
    }

    const reqRow = result.rows[0];
    const userId = reqRow.user_id as string;
    const email = reqRow.email as string;

    // Delete user (cascades will remove trips and related data)
    await this.deleteUserById(userId);

    // Clean up request
    await query('DELETE FROM account_deletion_requests WHERE id = $1', [reqRow.id]);

    // Send notification
    try { await EmailService.sendAccountDeletedNotification(email); } catch (_) {}

    return { success: true, message: 'Conta eliminada com sucesso' };
  }

  /**
   * Delete a user by id (permanent) - cascades will remove related data
   */
  async deleteUserById(userId: string): Promise<void> {
    // Perform a delete inside a transaction for safety
    await query('BEGIN');
    try {
      await query('DELETE FROM users WHERE id = $1', [userId]);
      await query('COMMIT');
    } catch (e) {
      await query('ROLLBACK');
      throw e;
    }
  }

  private generateToken(userId: string): string {
    return jwt.sign({ userId }, JWT_SECRET, { expiresIn: JWT_EXPIRES_IN });
  }
}

export const authService = new AuthService();
