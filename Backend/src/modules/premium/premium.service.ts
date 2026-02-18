import { query } from '../../config/database';

// Tipos de plano disponíveis
export type SubscriptionPlan = 'free' | 'basic' | 'premium';

// Limites por plano
export const PLAN_LIMITS = {
  free: {
    maxTrips: 2,
    maxActivitiesPerDay: 5,
    aiGenerationsPerMonth: 3,
    canExportPdf: false,
    canBackupCloud: false, // Sem backup cloud
    canAutoBackup: false,  // Backup manual local apenas
    canShareTrips: false,
    hasAds: true,
  },
  basic: {
    maxTrips: 10,
    maxActivitiesPerDay: 10,
    aiGenerationsPerMonth: 20,
    canExportPdf: true,
    canBackupCloud: true,  // Pode fazer backup para cloud
    canAutoBackup: true,   // Backup automático ativado
    canShareTrips: true,
    hasAds: true,
  },
  premium: {
    maxTrips: -1, // ilimitado
    maxActivitiesPerDay: -1, // ilimitado
    aiGenerationsPerMonth: -1, // ilimitado
    canExportPdf: true,
    canBackupCloud: true,
    canAutoBackup: true,   // Backup automático ativado
    canShareTrips: true,
    hasAds: false,
  },
};

export interface UserSubscriptionStatus {
  user_id: string;
  plan: SubscriptionPlan;
  subscription_since?: Date;
  subscription_expires_at?: Date;
  limits: typeof PLAN_LIMITS.free;
}

// Manter compatibilidade com código antigo
export interface UserPremiumStatus {
  user_id: string;
  is_premium: boolean;
  premium_since?: Date;
  premium_expires_at?: Date;
}

export class PremiumService {
  /**
   * Ativar/atualizar plano de um utilizador
   */
  async setUserPlan(userId: string, plan: SubscriptionPlan, expiresAt?: Date): Promise<void> {
    await query(
      `UPDATE users 
       SET subscription_plan = $2,
           is_premium = $3,
           premium_since = CASE WHEN $2 != 'free' THEN COALESCE(premium_since, CURRENT_TIMESTAMP) ELSE premium_since END,
           premium_expires_at = $4,
           updated_at = CURRENT_TIMESTAMP
       WHERE id = $1`,
      [userId, plan, plan !== 'free', expiresAt || null]
    );
  }

  /**
   * Ativar premium para um utilizador (retrocompatibilidade)
   */
  async activatePremium(userId: string, expiresAt?: Date): Promise<void> {
    await this.setUserPlan(userId, 'premium', expiresAt);
  }

  /**
   * Ativar plano basic para um utilizador
   */
  async activateBasic(userId: string, expiresAt?: Date): Promise<void> {
    await this.setUserPlan(userId, 'basic', expiresAt);
  }

  /**
   * Desativar plano pago (voltar para free)
   */
  async deactivatePremium(userId: string): Promise<void> {
    await this.setUserPlan(userId, 'free');
  }

  /**
   * Verificar status de subscrição de um utilizador
   */
  async getSubscriptionStatus(userId: string): Promise<UserSubscriptionStatus> {
    const result = await query<{
      user_id: string;
      subscription_plan: SubscriptionPlan;
      premium_since: Date;
      premium_expires_at: Date;
    }>(
      `SELECT 
        id as user_id,
        COALESCE(subscription_plan, CASE WHEN is_premium THEN 'premium' ELSE 'free' END) as subscription_plan,
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
    let plan: SubscriptionPlan = user.subscription_plan || 'free';

    // Verificar se subscrição expirou
    if (plan !== 'free' && user.premium_expires_at) {
      const now = new Date();
      if (new Date(user.premium_expires_at) < now) {
        // Expirado, voltar para free
        await this.setUserPlan(userId, 'free');
        plan = 'free';
      }
    }

    return {
      user_id: userId,
      plan,
      subscription_since: user.premium_since,
      subscription_expires_at: user.premium_expires_at,
      limits: PLAN_LIMITS[plan],
    };
  }

  /**
   * Verificar status premium de um utilizador (retrocompatibilidade)
   */
  async checkPremiumStatus(userId: string): Promise<UserPremiumStatus> {
    const status = await this.getSubscriptionStatus(userId);
    return {
      user_id: status.user_id,
      is_premium: status.plan !== 'free',
      premium_since: status.subscription_since,
      premium_expires_at: status.subscription_expires_at,
    };
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
   * Determina o plano baseado no product_id do Adapty
   */
  private getPlanFromProductId(productId: string): SubscriptionPlan {
    if (productId?.includes('basic')) {
      return 'basic';
    }
    if (productId?.includes('premium')) {
      return 'premium';
    }
    // Default para premium se não identificar
    return 'premium';
  }

  /**
   * Processar evento de webhook Adapty
   */
  async processAdaptyWebhook(event: any): Promise<void> {
    const { event_type, profile_email, subscription_expires_at, product_id } = event;

    // Encontrar utilizador pelo email
    const user = await this.getUserByEmail(profile_email);
    if (!user) {
      console.warn(`User not found for Adapty webhook: ${profile_email}`);
      return;
    }

    const plan = this.getPlanFromProductId(product_id);

    switch (event_type) {
      case 'subscription_started':
      case 'subscription_renewed':
        const expiresAt = subscription_expires_at ? new Date(subscription_expires_at) : undefined;
        await this.setUserPlan(user.id, plan, expiresAt);
        console.log(`✅ Plan ${plan} activated for user ${user.email}`);
        break;

      case 'subscription_cancelled':
      case 'subscription_expired':
      case 'subscription_refunded':
        await this.setUserPlan(user.id, 'free');
        console.log(`❌ Plan deactivated for user ${user.email} (now free)`);
        break;

      default:
        console.log(`ℹ️ Unhandled Adapty event type: ${event_type}`);
    }
  }
}
