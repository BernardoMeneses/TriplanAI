import { Router, Request, Response } from 'express';
import { authService } from './auth.service';

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

export const authController = router;
