import { Router, Request, Response } from 'express';
import { authService } from './auth.service';
import { authenticate } from '../../middlewares';

const router = Router();

/**
 * @swagger
 * /api/auth/register:
 *   post:
 *     summary: Registar novo utilizador
 *     tags: [Auth]
 *     security: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - email
 *               - password
 *               - full_name
 *             properties:
 *               email:
 *                 type: string
 *                 format: email
 *               password:
 *                 type: string
 *                 minLength: 6
 *               full_name:
 *                 type: string
 *               phone:
 *                 type: string
 *     responses:
 *       201:
 *         description: Utilizador registado com sucesso
 *       400:
 *         description: Dados inválidos
 */
router.post('/register', async (req: Request, res: Response) => {
  try {
    const { email, username, password, full_name, phone } = req.body;
    
    if (!email || !username || !password || !full_name) {
      return res.status(400).json({ error: 'Email, username, password e nome são obrigatórios' });
    }
    
    const result = await authService.register(email, password, full_name, username, phone);
    res.status(201).json(result);
  } catch (error: any) {
    res.status(400).json({ error: error.message || 'Erro ao registar utilizador' });
  }
});

/**
 * @swagger
 * /api/auth/login:
 *   post:
 *     summary: Autenticar utilizador
 *     tags: [Auth]
 *     security: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - email
 *               - password
 *             properties:
 *               email:
 *                 type: string
 *                 format: email
 *               password:
 *                 type: string
 *     responses:
 *       200:
 *         description: Login realizado com sucesso
 *       401:
 *         description: Credenciais inválidas
 */
router.post('/login', async (req: Request, res: Response) => {
  try {
    const { identifier, email, username, password } = req.body;
    const id = identifier || email || username;
    if (!id || !password) {
      return res.status(400).json({ error: 'Credenciais em falta' });
    }
    const result = await authService.login(id, password);
    res.json(result);
  } catch (error: any) {
    res.status(401).json({ error: error.message || 'Credenciais inválidas' });
  }
});

/**
 * @swagger
 * /api/auth/me:
 *   get:
 *     summary: Obter dados do utilizador autenticado
 *     tags: [Auth]
 *     responses:
 *       200:
 *         description: Dados do utilizador
 *       401:
 *         description: Não autenticado
 */
router.get('/me', async (req: Request, res: Response) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'Token não fornecido' });
    }

    const token = authHeader.split(' ')[1];
    const { valid, userId } = await authService.validateToken(token);

    if (!valid || !userId) {
      return res.status(401).json({ error: 'Token inválido' });
    }

    const user = await authService.getUserById(userId);
    if (!user) {
      return res.status(404).json({ error: 'Utilizador não encontrado' });
    }

    res.json(user);
  } catch (error) {
    res.status(401).json({ error: 'Erro de autenticação' });
  }
});

/**
 * @swagger
 * /api/auth/logout:
 *   post:
 *     summary: Terminar sessão
 *     tags: [Auth]
 *     responses:
 *       200:
 *         description: Logout realizado com sucesso
 */
router.post('/logout', async (req: Request, res: Response) => {
  // For JWT, logout is client-side (just delete the token)
  res.json({ success: true, message: 'Logout realizado com sucesso' });
});

/**
 * @swagger
 * /api/auth/verify-email:
 *   post:
 *     summary: Verificar email com token
 *     tags: [Auth]
 *     security: []
 */
router.post('/verify-email', async (req: Request, res: Response) => {
  try {
    const { token } = req.body;
    if (!token) {
      return res.status(400).json({ error: 'Token não fornecido' });
    }
    const result = await authService.verifyEmail(token);
    res.json(result);
  } catch (error: any) {
    res.status(400).json({ error: error.message || 'Erro ao verificar email' });
  }
});

/**
 * @swagger
 * /api/auth/resend-verification:
 *   post:
 *     summary: Reenviar email de verificação
 *     tags: [Auth]
 *     security: []
 */
router.post('/resend-verification', async (req: Request, res: Response) => {
  try {
    const { email } = req.body;
    if (!email) {
      return res.status(400).json({ error: 'Email não fornecido' });
    }
    const result = await authService.resendVerificationEmail(email);
    res.json(result);
  } catch (error: any) {
    res.status(400).json({ error: error.message || 'Erro ao reenviar email' });
  }
});

/**
 * @swagger
 * /api/auth/forgot-password:
 *   post:
 *     summary: Solicitar reset de password
 *     tags: [Auth]
 *     security: []
 */
router.post('/forgot-password', async (req: Request, res: Response) => {
  try {
    const { email } = req.body;
    if (!email) {
      return res.status(400).json({ error: 'Email não fornecido' });
    }
    const result = await authService.requestPasswordReset(email);
    res.json(result);
  } catch (error: any) {
    res.status(400).json({ error: error.message || 'Erro ao processar pedido' });
  }
});

/**
 * @swagger
 * /api/auth/reset-password:
 *   post:
 *     summary: Reset password com token
 *     tags: [Auth]
 *     security: []
 */
router.post('/reset-password', async (req: Request, res: Response) => {
  try {
    const { token, password } = req.body;
    if (!token || !password) {
      return res.status(400).json({ error: 'Token e password são obrigatórios' });
    }
    if (password.length < 6) {
      return res.status(400).json({ error: 'Password deve ter pelo menos 6 caracteres' });
    }
    const result = await authService.resetPassword(token, password);
    res.json(result);
  } catch (error: any) {
    res.status(400).json({ error: error.message || 'Erro ao redefinir password' });
  }
});

/**
 * @swagger
 * /api/auth/google:
 *   post:
 *     summary: Login com Google
 *     tags: [Auth]
 *     security: []
 */
router.post('/google', async (req: Request, res: Response) => {
  try {
    const { googleId, email, name, picture, accessToken, refreshToken } = req.body;
    
    if (!googleId || !email || !name || !accessToken) {
      return res.status(400).json({ error: 'Dados do Google incompletos' });
    }

    const result = await authService.googleLogin({
      googleId,
      email,
      name,
      picture,
      accessToken,
      refreshToken,
    });

    res.json(result);
  } catch (error: any) {
    res.status(400).json({ error: error.message || 'Erro no login com Google' });
  }
});

export const authController = router;

// Account deletion endpoints
// POST /api/auth/delete-request { email }
router.post('/delete-request', async (req: Request, res: Response) => {
  try {
    const { email } = req.body;
    if (!email) return res.status(400).json({ error: 'Email não fornecido' });
    const result = await authService.requestAccountDeletion(email);
    res.json(result);
  } catch (error: any) {
    res.status(500).json({ error: error.message || 'Erro ao processar pedido' });
  }
});

// POST /api/auth/delete-confirm { token }
router.post('/delete-confirm', async (req: Request, res: Response) => {
  try {
    const { token } = req.body;
    if (!token) return res.status(400).json({ error: 'Token não fornecido' });
    const result = await authService.confirmAccountDeletion(token);
    res.json(result);
  } catch (error: any) {
    res.status(400).json({ error: error.message || 'Token inválido' });
  }
});

// DELETE /api/auth/me -> in-app authenticated deletion
router.delete('/me', authenticate, async (req: Request, res: Response) => {
  try {
    if (!req.user) return res.status(401).json({ error: 'Não autenticado' });
    const userId = req.user.id;
    await authService.deleteUserById(userId);
    try { await import('../../services/email.service').then(s => s.EmailService.sendAccountDeletedNotification(req.user!.email)); } catch(_){}
    res.json({ success: true, message: 'Conta eliminada com sucesso' });
  } catch (error: any) {
    res.status(500).json({ error: error.message || 'Erro ao eliminar conta' });
  }
});
