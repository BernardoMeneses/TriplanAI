import { Router, Request, Response } from 'express';
import { PremiumService, PLAN_LIMITS } from './premium.service';

const router = Router();
const premiumService = new PremiumService();

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
    const event = req.body;
    
    // Log do evento
    console.log('📥 Adapty webhook received:', {
      event_type: event.event_type,
      profile_email: event.profile_email,
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

    const { productId, purchaseToken, expiresAt } = req.body;
    
    console.log('📱 Premium sync request:', {
      userId,
      productId,
      purchaseToken: purchaseToken ? '***' : undefined,
      expiresAt,
      timestamp: new Date().toISOString(),
    });

    // Determinar o plano baseado no productId
    let plan: 'basic' | 'premium' = 'premium';
    if (productId) {
      if (productId.includes('basic')) {
        plan = 'basic';
      } else if (productId.includes('premium')) {
        plan = 'premium';
      }
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
