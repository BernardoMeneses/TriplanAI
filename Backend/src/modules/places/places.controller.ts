import { Router, Request, Response } from 'express';
import { placesService } from './places.service';

const router = Router();

/**
 * @swagger
 * /api/places/search:
 *   get:
 *     summary: Pesquisar locais
 *     tags: [Places]
 *     parameters:
 *       - in: query
 *         name: query
 *         required: true
 *         schema:
 *           type: string
 *         description: Termo de pesquisa
 *       - in: query
 *         name: lat
 *         schema:
 *           type: number
 *         description: Latitude para pesquisa por proximidade
 *       - in: query
 *         name: lng
 *         schema:
 *           type: number
 *         description: Longitude para pesquisa por proximidade
 *     responses:
 *       200:
 *         description: Lista de locais encontrados
 */
router.get('/search', async (req: Request, res: Response) => {
  try {
    const { query, lat, lng } = req.query;
    const location = lat && lng ? { lat: Number(lat), lng: Number(lng) } : undefined;
    const places = await placesService.searchPlaces(query as string, location);
    res.json(places);
  } catch (error) {
    res.status(400).json({ error: 'Erro ao pesquisar locais' });
  }
});

/**
 * @swagger
 * /api/places/nearby:
 *   get:
 *     summary: Obter locais próximos
 *     tags: [Places]
 *     parameters:
 *       - in: query
 *         name: lat
 *         required: true
 *         schema:
 *           type: number
 *       - in: query
 *         name: lng
 *         required: true
 *         schema:
 *           type: number
 *       - in: query
 *         name: radius
 *         schema:
 *           type: number
 *         description: Raio em metros (default 1000)
 *       - in: query
 *         name: type
 *         schema:
 *           type: string
 *         description: Tipo de local (restaurant, hotel, attraction, etc.)
 *     responses:
 *       200:
 *         description: Lista de locais próximos
 */
router.get('/nearby', async (req: Request, res: Response) => {
  try {
    const { lat, lng, radius, type } = req.query;
    const places = await placesService.getNearbyPlaces(
      Number(lat),
      Number(lng),
      Number(radius) || 1000,
      type as string
    );
    res.json(places);
  } catch (error) {
    res.status(400).json({ error: 'Erro ao obter locais próximos' });
  }
});

/**
 * @swagger
 * /api/places/popular/{destination}:
 *   get:
 *     summary: Obter locais populares de um destino
 *     tags: [Places]
 *     parameters:
 *       - in: path
 *         name: destination
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Lista de locais populares
 */
router.get('/popular/:destination', async (req: Request, res: Response) => {
  try {
    const places = await placesService.getPopularPlaces(req.params.destination);
    res.json(places);
  } catch (error) {
    res.status(400).json({ error: 'Erro ao obter locais populares' });
  }
});

/**
 * @swagger
 * /api/places/{id}:
 *   get:
 *     summary: Obter detalhes de um local
 *     tags: [Places]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Detalhes do local
 *       404:
 *         description: Local não encontrado
 */
router.get('/:id', async (req: Request, res: Response) => {
  try {
    const place = await placesService.getPlaceById(req.params.id);
    if (!place) {
      return res.status(404).json({ error: 'Local não encontrado' });
    }
    res.json(place);
  } catch (error) {
    res.status(400).json({ error: 'Erro ao obter detalhes do local' });
  }
});

export const placesController = router;
