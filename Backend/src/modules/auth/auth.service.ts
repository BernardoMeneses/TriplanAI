import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import { query } from '../../config/database';

const JWT_SECRET = process.env.JWT_SECRET || 'triplanai-secret-key-change-in-production';
const JWT_EXPIRES_IN = '365d'; // Token válido por 1 ano para testes
const SALT_ROUNDS = 10;

export interface User {
  id: string;
  email: string;
  username: string;
  password_hash: string;
  full_name: string;
  phone?: string;
  profile_picture_url?: string;
  preferences?: Record<string, any>;
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
  ): Promise<{ user: Omit<User, 'password_hash'>; token: string }> {
    // Check if user already exists
    const existingUser = await query('SELECT id FROM users WHERE email = $1 OR username = $2', [email, username]);
    if (existingUser.rows.length > 0) {
      throw new Error('Email ou username já registado');
    }

    // Hash password
    const passwordHash = await bcrypt.hash(password, SALT_ROUNDS);

    // Create user
    const result = await query<User>(
      `INSERT INTO users (email, username, password_hash, full_name, phone)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING id, email, username, full_name, phone, profile_picture_url, preferences, created_at, updated_at, is_active`,
      [email, username, passwordHash, fullName, phone || null]
    );

    const user = result.rows[0];
    const token = this.generateToken(user.id);

    return { user, token };
  }

  async login(identifier: string, password: string): Promise<{ user: Omit<User, 'password_hash'>; token: string }> {
    // Find user by email or username
    const result = await query<User>('SELECT * FROM users WHERE (email = $1 OR username = $1) AND is_active = true', [identifier]);
    
    if (result.rows.length === 0) {
      throw new Error('Credenciais inválidas');
    }

    const user = result.rows[0];

    // Verify password
    const isValidPassword = await bcrypt.compare(password, user.password_hash);
    if (!isValidPassword) {
      throw new Error('Credenciais inválidas');
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

  private generateToken(userId: string): string {
    return jwt.sign({ userId }, JWT_SECRET, { expiresIn: JWT_EXPIRES_IN });
  }
}

export const authService = new AuthService();
