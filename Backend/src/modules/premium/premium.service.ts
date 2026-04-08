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
    canBackupCloud: false,
    canAutoBackup: false,
    canShareTrips: false,
    hasAds: true,
  },
  basic: {
    maxTrips: 10,
    maxActivitiesPerDay: 10,
    aiGenerationsPerMonth: 20,
    canExportPdf: true,
    canBackupCloud: true,
    canAutoBackup: true,
    canShareTrips: true,
    hasAds: true,
  },
  premium: {
    maxTrips: -1,
    maxActivitiesPerDay: -1,
    aiGenerationsPerMonth: -1,
    canExportPdf: true,
    canBackupCloud: true,
    canAutoBackup: true,
    canShareTrips: true,
    hasAds: false,
  },
};

export interface UserSubscriptionStatus {
  user_id: string;
  plan: SubscriptionPlan;
  limits: typeof PLAN_LIMITS.free;
}

export class PremiumService {
  /**
   * Definir plano de um utilizador
   */
  async setUserPlan(userId: string, plan: SubscriptionPlan): Promise<void> {
    await query(
      `UPDATE users 
       SET subscription_plan = $2,
           updated_at = CURRENT_TIMESTAMP
       WHERE id = $1`,
      [userId, plan]
    );
  }

  /**
   * Obter status de subscrição de um utilizador
   */
  async getSubscriptionStatus(userId: string): Promise<UserSubscriptionStatus & { ai_generations_used: number; trips_used: number }> {
    const result = await query<{
      user_id: string;
      subscription_plan: SubscriptionPlan;
      ai_generations_this_month: number;
      ai_generations_reset_at: Date;
    }>(
      `SELECT 
        id as user_id,
        COALESCE(subscription_plan::text, 'free')::text as subscription_plan,
        COALESCE(ai_generations_this_month, 0) as ai_generations_this_month,
        ai_generations_reset_at
       FROM users 
       WHERE id = $1`,
      [userId]
    );

    if (result.rows.length === 0) {
      throw new Error('User not found');
    }

    const user = result.rows[0];
    const plan: SubscriptionPlan = user.subscription_plan || 'free';

    // Reset mensal do contador de IA
    let aiUsed = user.ai_generations_this_month || 0;
    if (user.ai_generations_reset_at) {
      const resetDate = new Date(user.ai_generations_reset_at);
      const now = new Date();
      if (now.getMonth() !== resetDate.getMonth() || now.getFullYear() !== resetDate.getFullYear()) {
        await query(
          `UPDATE users SET ai_generations_this_month = 0, ai_generations_reset_at = CURRENT_TIMESTAMP WHERE id = $1`,
          [userId]
        );
        aiUsed = 0;
      }
    }

    const tripUsageResult = await query<{ total: number | string }>(
      `SELECT COALESCE(
          SUM(
            CASE
              WHEN t.user_id = $1 THEN
                1 + COALESCE(
                  CASE
                    WHEN (COALESCE(t.preferences, '{}'::jsonb)->>'replacement_count') ~ '^[0-9]+$'
                      THEN (COALESCE(t.preferences, '{}'::jsonb)->>'replacement_count')::int
                    ELSE 0
                  END,
                  0
                )
              ELSE 1
            END
          ),
          0
        )::int AS total
       FROM trips t
       WHERE t.user_id = $1
          OR EXISTS (
            SELECT 1
            FROM trip_members tm
            WHERE tm.trip_id = t.id
              AND tm.user_id = $1
          )`,
      [userId]
    );

    const tripsUsed = Number(tripUsageResult.rows[0]?.total ?? 0) || 0;

    return {
      user_id: userId,
      plan,
      limits: PLAN_LIMITS[plan],
      ai_generations_used: aiUsed,
      trips_used: tripsUsed,
    };
  }

  /**
   * Incrementar contador de gerações de IA
   */
  async incrementAIGenerations(userId: string): Promise<void> {
    await query(
      `UPDATE users 
       SET ai_generations_this_month = COALESCE(ai_generations_this_month, 0) + 1,
           updated_at = CURRENT_TIMESTAMP
       WHERE id = $1`,
      [userId]
    );
  }

  /**
   * Verificar se utilizador pode usar IA (dentro dos limites do plano)
   */
  async canUseAI(userId: string): Promise<{ allowed: boolean; used: number; limit: number }> {
    const status = await this.getSubscriptionStatus(userId);
    const limit = status.limits.aiGenerationsPerMonth;
    if (limit === -1) return { allowed: true, used: status.ai_generations_used, limit: -1 };
    return {
      allowed: status.ai_generations_used < limit,
      used: status.ai_generations_used,
      limit,
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
  private getPlanFromProductId(productId: string): SubscriptionPlan | null {
    const normalizedProductId = (productId || '').toLowerCase();

    if (normalizedProductId.includes('basic')) {
      return 'basic';
    }
    if (normalizedProductId.includes('premium')) {
      return 'premium';
    }

    return null;
  }

  /**
   * Processar evento de webhook Adapty
   */
  async processAdaptyWebhook(event: any): Promise<void> {
    const { event_type, profile_email, product_id } = event;

    const user = await this.getUserByEmail(profile_email);
    if (!user) {
      console.warn(`User not found for Adapty webhook: ${profile_email}`);
      return;
    }

    const plan = this.getPlanFromProductId(product_id);

    if (!plan && (event_type === 'subscription_started' || event_type === 'subscription_renewed')) {
      console.warn(
        `Unknown Adapty product_id in webhook for ${user.email}: ${product_id}`
      );
      return;
    }

    switch (event_type) {
      case 'subscription_started':
      case 'subscription_renewed': {
        // Extra guard para manter type-safety em tempo de compilação.
        if (!plan) {
          console.warn(
            `Cannot activate plan for ${user.email}: unknown product_id ${product_id}`
          );
          return;
        }

        await this.setUserPlan(user.id, plan);
        console.log(`✅ Plan ${plan} activated for user ${user.email}`);
        break;
      }

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
