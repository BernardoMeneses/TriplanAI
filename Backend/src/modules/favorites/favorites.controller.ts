import { Router, Request, Response } from 'express';
import { FavoritesService } from './favorites.service';

const router = Router();
const favoritesService = new FavoritesService();

/**
 * @swagger
 * /api/favorites:
 *   get:
 *     summary: Obter favoritos do utilizador
 *     tags: [Favorites]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Lista de favoritos
 */
router.get('/', async (req: Request, res: Response) => {
  try {
    const userId = (req as any).user?.id;
    if (!userId) {
      return res.status(401).json({ error: 'Não autenticado' });
    }

    const favorites = await favoritesService.getFavorites(userId);
    res.json(favorites);
  } catch (error) {
    console.error('Erro ao obter favoritos:', error);
    res.status(500).json({ error: 'Erro ao obter favoritos' });
  }
});

/**
 * @swagger
 * /api/favorites/{placeId}:
 *   post:
 *     summary: Adicionar lugar aos favoritos
 *     tags: [Favorites]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: placeId
 *         required: true
 *         schema:
 *           type: string
 *     requestBody:
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               notes:
 *                 type: string
 *     responses:
 *       200:
 *         description: Favorito adicionado
 */
router.post('/:placeId', async (req: Request, res: Response) => {
  try {
    const userId = (req as any).user?.id;
    if (!userId) {
      return res.status(401).json({ error: 'Não autenticado' });
    }

    const { placeId } = req.params;
    const { notes } = req.body;

    const favorite = await favoritesService.addFavorite(userId, placeId, notes);
    res.json(favorite);
  } catch (error) {
    console.error('Erro ao adicionar favorito:', error);
    res.status(500).json({ error: 'Erro ao adicionar favorito' });
  }
});

/**
 * @swagger
 * /api/favorites/{placeId}:
 *   delete:
 *     summary: Remover lugar dos favoritos
 *     tags: [Favorites]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: placeId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Favorito removido
 */
router.delete('/:placeId', async (req: Request, res: Response) => {
  try {
    const userId = (req as any).user?.id;
    if (!userId) {
      return res.status(401).json({ error: 'Não autenticado' });
    }

    const { placeId } = req.params;
    const removed = await favoritesService.removeFavorite(userId, placeId);

    if (!removed) {
      return res.status(404).json({ error: 'Favorito não encontrado' });
    }

    res.json({ message: 'Favorito removido com sucesso' });
  } catch (error) {
    console.error('Erro ao remover favorito:', error);
    res.status(500).json({ error: 'Erro ao remover favorito' });
  }
});

/**
 * @swagger
 * /api/favorites/check/{placeId}:
 *   get:
 *     summary: Verificar se um lugar é favorito
 *     tags: [Favorites]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: placeId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Status de favorito
 */
router.get('/check/:placeId', async (req: Request, res: Response) => {
  try {
    const userId = (req as any).user?.id;
    if (!userId) {
      return res.status(401).json({ error: 'Não autenticado' });
    }

    const { placeId } = req.params;
    const isFavorite = await favoritesService.isFavorite(userId, placeId);

    res.json({ isFavorite });
  } catch (error) {
    console.error('Erro ao verificar favorito:', error);
    res.status(500).json({ error: 'Erro ao verificar favorito' });
  }
});

export default router;
