import { Router, Request, Response } from 'express';
import { PremiumService } from './premium.service';

const router = Router();
const premiumService = new PremiumService();

/**
 * @swagger
 * /api/premium/status:
 *   get:
 *     summary: Verificar status premium do utilizador
 *     tags: [Premium]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Status premium
 *       401:
 *         description: Not authenticated
 */
router.get('/status', async (req: Request, res: Response) => {
  try {
    const userId = (req as any).user?.id;
    if (!userId) {
      return res.status(401).json({ error: 'Not authenticated' });
    }

    const status = await premiumService.checkPremiumStatus(userId);
    res.json(status);
  } catch (error) {
    console.error('Error checking premium status:', error);
    res.status(500).json({ error: 'Error checking premium status' });
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

    const { expiresAt } = req.body;
    const expiresDate = expiresAt ? new Date(expiresAt) : undefined;

    await premiumService.activatePremium(userId, expiresDate);
    
    res.json({ 
      success: true, 
      message: 'Premium activated',
      expires_at: expiresDate,
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

    await premiumService.deactivatePremium(userId);
    
    res.json({ 
      success: true, 
      message: 'Premium deactivated',
    });
  } catch (error) {
    console.error('Error deactivating premium:', error);
    res.status(500).json({ error: 'Error deactivating premium' });
  }
});

export default router;
