import { Router, Request, Response } from 'express';
import { FavoritesService } from './favorites.service';
import { MapsService } from '../maps/maps.service';

const router = Router();
const favoritesService = new FavoritesService();
const mapsService = new MapsService();

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
    
    // Regenerar URLs das imagens a partir das referências (se tiverem)
    const favoritesWithFreshImages = favorites.map(favorite => {
      if (!favorite.place) return favorite;

      // Se tiver photoReferences, regenera as URLs frescas
      if (favorite.place.photo_references && Array.isArray(favorite.place.photo_references) && favorite.place.photo_references.length > 0) {
        try {
          const photoRefs = favorite.place.photo_references as Array<{ reference: string; type: string }>;
          const { photos, photoUrl } = mapsService.regeneratePhotoUrlsFromReferences(photoRefs);
          return {
            ...favorite,
            place: {
              ...favorite.place,
              photos,
              photoUrl // Adiciona o campo photoUrl para o frontend usar
            }
          };
        } catch (error) {
          console.error('Erro ao regenerar URLs de fotos:', error);
          // Se falhar, usar as imagens antigas como fallback
          return {
            ...favorite,
            place: {
              ...favorite.place,
              photoUrl: favorite.place.images?.length > 0 ? favorite.place.images[0] : null
            }
          };
        }
      }
      
      // Se não tiver photoReferences, usado as imagens antigas ou fallback
      return {
        ...favorite,
        place: {
          ...favorite.place,
          photoUrl: favorite.place.images?.length > 0 ? favorite.place.images[0] : null
        }
      };
    });
    
    res.json(favoritesWithFreshImages);
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
