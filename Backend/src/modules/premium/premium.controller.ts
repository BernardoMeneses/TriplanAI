import { Router, Request, Response } from 'express';
import { timingSafeEqual } from 'crypto';
import { PremiumService } from './premium.service';

const router = Router();
const premiumService = new PremiumService();

function getConfiguredWebhookAuthTokens(envKeys: string[]): string[] {
  const tokens = new Set<string>();

  for (const key of envKeys) {
    const rawValue = process.env[key];
    if (!rawValue) continue;

    const values = rawValue
      .split(',')
      .map((value) => value.trim())
      .filter((value) => value.length > 0);

    for (const value of values) {
      tokens.add(value);
    }
  }

  return [...tokens];
}

const adaptyWebhookAuthTokens = getConfiguredWebhookAuthTokens([
  'ADAPTY_WEBHOOK_AUTHORIZATION',
  'ADAPTY_WEBHOOK_AUTHORIZATION_PRODUCTION',
  'ADAPTY_WEBHOOK_AUTHORIZATION_SANDBOX',
  'ADAPTY_WEBHOOK_AUTH_TOKENS',
]);

if (adaptyWebhookAuthTokens.length === 0) {
  throw new Error(
    'Adapty webhook authorization must be configured via ADAPTY_WEBHOOK_AUTHORIZATION (or related env keys).',
  );
}

function timingSafeStringEquals(left: string, right: string): boolean {
  const leftBuffer = Buffer.from(left);
  const rightBuffer = Buffer.from(right);

  if (leftBuffer.length !== rightBuffer.length) {
    return false;
  }

  return timingSafeEqual(leftBuffer, rightBuffer);
}

function isAuthorizedAdaptyWebhookRequest(headerValue?: string): boolean {
  if (!headerValue) {
    return false;
  }

  const normalizedHeader = headerValue.trim();
  return adaptyWebhookAuthTokens.some((token) =>
    timingSafeStringEquals(normalizedHeader, token),
  );
}

/**
 * @swagger
 * /api/premium/status:
 *   get:
 *     summary: Verificar status de subscrição do utilizador
 *     tags: [Premium]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Status da subscrição com limites do plano
 *       401:
 *         description: Not authenticated
 */
router.get('/status', async (req: Request, res: Response) => {
  try {
    const userId = (req as any).user?.id;
    if (!userId) {
      return res.status(401).json({ error: 'Not authenticated' });
    }

    const status = await premiumService.getSubscriptionStatus(userId);
    
    res.json({
      plan: status.plan,
      limits: status.limits,
      ai_generations_used: status.ai_generations_used,
      trips_used: status.trips_used,
    });
  } catch (error) {
    console.error('Error checking subscription status:', error);
    res.status(500).json({ error: 'Error checking subscription status' });
  }
});

/**
 * @swagger
 * /api/premium/adapty-webhook:
 *   post:
 *     summary: Webhook para eventos do Adapty
 *     tags: [Premium]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *     responses:
 *       200:
 *         description: Webhook processed
 *       400:
 *         description: Invalid webhook
 */
router.post('/adapty-webhook', async (req: Request, res: Response) => {
  try {
    const authorizationHeader = req.get('authorization');
    if (!isAuthorizedAdaptyWebhookRequest(authorizationHeader)) {
      return res.status(401).json({ error: 'Unauthorized webhook request' });
    }

    const event = req.body as Record<string, unknown> | null;
    if (!event || typeof event !== 'object' || Array.isArray(event)) {
      return res.status(400).json({ error: 'Invalid webhook payload' });
    }

    // Adapty sends an empty JSON object as verification payload when enabling integration.
    if (Object.keys(event).length === 0) {
      return res.status(200).json({ success: true, verification: true });
    }

    const eventType =
      typeof event.event_type === 'string' ? event.event_type : undefined;
    const profileEmail =
      typeof event.profile_email === 'string'
        ? event.profile_email
        : typeof event.email === 'string'
          ? event.email
          : undefined;
    
    // Log do evento
    console.log('📥 Adapty webhook received:', {
      event_type: eventType,
      profile_email: profileEmail,
      timestamp: new Date().toISOString(),
    });

    // Processar evento
    await premiumService.processAdaptyWebhook(event);

    res.json({ success: true });
  } catch (error) {
    console.error('Error processing Adapty webhook:', error);
    res.status(500).json({ error: 'Error processing webhook' });
  }
});

/**
 * @swagger
 * /api/premium/activate:
 *   post:
 *     summary: Ativar premium manualmente (admin/testing)
 *     tags: [Premium]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               expiresAt:
 *                 type: string
 *                 format: date-time
 *     responses:
 *       200:
 *         description: Premium activated
 */
router.post('/activate', async (req: Request, res: Response) => {
  try {
    const userId = (req as any).user?.id;
    if (!userId) {
      return res.status(401).json({ error: 'Not authenticated' });
    }

    const { plan } = req.body;
    const targetPlan = plan === 'basic' ? 'basic' : 'premium';

    await premiumService.setUserPlan(userId, targetPlan);
    
    res.json({ 
      success: true, 
      message: `${targetPlan} plan activated`,
    });
  } catch (error) {
    console.error('Error activating premium:', error);
    res.status(500).json({ error: 'Error activating premium' });
  }
});

/**
 * @swagger
 * /api/premium/deactivate:
 *   post:
 *     summary: Desativar premium manualmente (admin/testing)
 *     tags: [Premium]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Premium deactivated
 */
router.post('/deactivate', async (req: Request, res: Response) => {
  try {
    const userId = (req as any).user?.id;
    if (!userId) {
      return res.status(401).json({ error: 'Not authenticated' });
    }

    await premiumService.setUserPlan(userId, 'free');
    
    res.json({ 
      success: true, 
      message: 'Plan set to free',
    });
  } catch (error) {
    console.error('Error deactivating premium:', error);
    res.status(500).json({ error: 'Error deactivating premium' });
  }
});

/**
 * @swagger
 * /api/premium/sync:
 *   post:
 *     summary: Sincronizar compra do app com o backend (backup ao webhook)
 *     tags: [Premium]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               productId:
 *                 type: string
 *                 description: ID do produto comprado (ex: triplan_premium_monthly)
 *               purchaseToken:
 *                 type: string
 *                 description: Token da compra do Adapty
 *               expiresAt:
 *                 type: string
 *                 format: date-time
 *                 description: Data de expiração da subscrição
 *     responses:
 *       200:
 *         description: Subscription synced successfully
 *       401:
 *         description: Not authenticated
 */
router.post('/sync', async (req: Request, res: Response) => {
  try {
    const userId = (req as any).user?.id;
    if (!userId) {
      return res.status(401).json({ error: 'Not authenticated' });
    }

    const { productId, purchaseToken, expiresAt, plan: requestedPlan } =
      req.body;
    
    console.log('📱 Premium sync request:', {
      userId,
      productId,
      requestedPlan,
      purchaseToken: purchaseToken ? '***' : undefined,
      expiresAt,
      timestamp: new Date().toISOString(),
    });

    // Determinar plano com prioridade ao productId; usar `plan` como fallback.
    let plan: 'basic' | 'premium' | null = null;

    if (typeof productId === 'string' && productId.trim().length > 0) {
      const normalizedProductId = productId.toLowerCase();
      if (normalizedProductId.includes('basic')) {
        plan = 'basic';
      } else if (normalizedProductId.includes('premium')) {
        plan = 'premium';
      }
    }

    if (!plan && typeof requestedPlan === 'string') {
      const normalizedPlan = requestedPlan.toLowerCase();
      if (normalizedPlan === 'basic') {
        plan = 'basic';
      } else if (normalizedPlan === 'premium') {
        plan = 'premium';
      }
    }

    if (!plan) {
      return res.status(400).json({
        error:
          'Missing or invalid subscription plan. Provide productId or plan (basic|premium).',
      });
    }

    // Ativar o plano
    await premiumService.setUserPlan(userId, plan);

    // Obter status atualizado
    const status = await premiumService.getSubscriptionStatus(userId);

    res.json({ 
      success: true, 
      message: `${plan} plan activated`,
      plan: status.plan,
      limits: status.limits,
    });
  } catch (error) {
    console.error('Error syncing premium:', error);
    res.status(500).json({ error: 'Error syncing subscription' });
  }
});

export default router;
