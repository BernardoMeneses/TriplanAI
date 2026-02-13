import { query } from '../../config/database';

export interface UserPremiumStatus {
  user_id: string;
  is_premium: boolean;
  premium_since?: Date;
  premium_expires_at?: Date;
}

export class PremiumService {
  /**
   * Ativar premium para um utilizador
   */
  async activatePremium(userId: string, expiresAt?: Date): Promise<void> {
    await query(
      `UPDATE users 
       SET is_premium = true, 
           premium_since = COALESCE(premium_since, CURRENT_TIMESTAMP),
           premium_expires_at = $2,
           updated_at = CURRENT_TIMESTAMP
       WHERE id = $1`,
      [userId, expiresAt || null]
    );
  }

  /**
   * Desativar premium para um utilizador
   */
  async deactivatePremium(userId: string): Promise<void> {
    await query(
      `UPDATE users 
       SET is_premium = false,
           updated_at = CURRENT_TIMESTAMP
       WHERE id = $1`,
      [userId]
    );
  }

  /**
   * Verificar status premium de um utilizador
   */
  async checkPremiumStatus(userId: string): Promise<UserPremiumStatus> {
    const result = await query<UserPremiumStatus>(
      `SELECT 
        id as user_id,
        is_premium,
        premium_since,
        premium_expires_at
       FROM users 
       WHERE id = $1`,
      [userId]
    );

    if (result.rows.length === 0) {
      throw new Error('User not found');
    }

    const user = result.rows[0];

    // Verificar se premium expirou
    if (user.is_premium && user.premium_expires_at) {
      const now = new Date();
      if (new Date(user.premium_expires_at) < now) {
        // Premium expirado, desativar
        await this.deactivatePremium(userId);
        return {
          user_id: userId,
          is_premium: false,
        };
      }
    }

    return user;
  }

  /**
   * Obter utilizador por email (para webhooks Adapty)
   */
  async getUserByEmail(email: string): Promise<{ id: string; email: string } | null> {
    const result = await query<{ id: string; email: string }>(
      'SELECT id, email FROM users WHERE email = $1',
      [email]
    );
    return result.rows[0] || null;
  }

  /**
   * Processar evento de webhook Adapty
   */
  async processAdaptyWebhook(event: any): Promise<void> {
    const { event_type, profile_id, profile_email, subscription_expires_at } = event;

    // Encontrar utilizador pelo email
    const user = await this.getUserByEmail(profile_email);
    if (!user) {
      console.warn(`User not found for Adapty webhook: ${profile_email}`);
      return;
    }

    switch (event_type) {
      case 'subscription_started':
      case 'subscription_renewed':
        // Ativar premium
        const expiresAt = subscription_expires_at ? new Date(subscription_expires_at) : undefined;
        await this.activatePremium(user.id, expiresAt);
        console.log(`✅ Premium activated for user ${user.email}`);
        break;

      case 'subscription_cancelled':
      case 'subscription_expired':
      case 'subscription_refunded':
        // Desativar premium
        await this.deactivatePremium(user.id);
        console.log(`❌ Premium deactivated for user ${user.email}`);
        break;

      default:
        console.log(`ℹ️ Unhandled Adapty event type: ${event_type}`);
    }
  }
}
