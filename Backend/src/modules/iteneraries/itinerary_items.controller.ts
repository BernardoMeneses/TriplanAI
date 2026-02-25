import { Router, Request, Response } from 'express';
import { ItineraryItemsService } from './itinerary_items.service';

const router = Router();
const itineraryItemsService = new ItineraryItemsService();

/**
 * @swagger
 * /api/itinerary-items:
 *   post:
 *     summary: Criar novo item do itinerario
 *     tags: [Itinerary Items]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - itineraryId
 *               - title
 *               - orderIndex
 *             properties:
 *               itineraryId:
 *                 type: string
 *               title:
 *                 type: string
 *               description:
 *                 type: string
 *               startTime:
 *                 type: string
 *               endTime:
 *                 type: string
 *               orderIndex:
 *                 type: number
 *               placeId:
 *                 type: string
 *               latitude:
 *                 type: number
 *               longitude:
 *                 type: number
 *               transportMode:
 *                 type: string
 *               duration:
 *                 type: number
 *               distance:
 *                 type: number
 *     responses:
 *       201:
 *         description: Item criado com sucesso
 */
router.post('/', async (req: Request, res: Response) => {
  try {
    const item = await itineraryItemsService.createItineraryItem(req.body);
    res.status(201).json(item);
  } catch (error) {
    console.error('Erro ao criar item do itinerario:', error);
    res.status(400).json({ error: 'Erro ao criar item do itinerario' });
  }
});

/**
 * @swagger
 * /api/itinerary-items/itinerary/{itineraryId}:
 *   get:
 *     summary: Listar items de um itinerario
 *     tags: [Itinerary Items]
 *     parameters:
 *       - in: path
 *         name: itineraryId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Lista de items do itinerario
 */
router.get('/itinerary/:itineraryId', async (req: Request, res: Response) => {
  try {
    const items = await itineraryItemsService.getItineraryItemsByDay(req.params.itineraryId);
    res.json(items);
  } catch (error) {
    console.error('Erro ao listar items do itinerario:', error);
    res.status(400).json({ error: 'Erro ao listar items do itinerario' });
  }
});

/**
 * @swagger
 * /api/itinerary-items/{id}:
 *   get:
 *     summary: Obter item por ID
 *     tags: [Itinerary Items]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Detalhes do item
 *       404:
 *         description: Item nao encontrado
 */
router.get('/:id', async (req: Request, res: Response) => {
  try {
    const item = await itineraryItemsService.getItineraryItemById(req.params.id);
    if (!item) {
      return res.status(404).json({ error: 'Item nao encontrado' });
    }
    res.json(item);
  } catch (error) {
    console.error('Erro ao obter item:', error);
    res.status(400).json({ error: 'Erro ao obter item do itinerario' });
  }
});

/**
 * @swagger
 * /api/itinerary-items/{id}:
 *   put:
 *     summary: Atualizar item do itinerario
 *     tags: [Itinerary Items]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *     responses:
 *       200:
 *         description: Item atualizado
 *       404:
 *         description: Item nao encontrado
 */
router.put('/:id', async (req: Request, res: Response) => {
  try {
    const item = await itineraryItemsService.updateItineraryItem(req.params.id, req.body);
    if (!item) {
      return res.status(404).json({ error: 'Item nao encontrado' });
    }
    res.json(item);
  } catch (error) {
    console.error('Erro ao atualizar item:', error);
    res.status(400).json({ error: 'Erro ao atualizar item do itinerario' });
  }
});

/**
 * @swagger
 * /api/itinerary-items/{id}:
 *   delete:
 *     summary: Eliminar item do itinerario
 *     tags: [Itinerary Items]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Item eliminado
 *       404:
 *         description: Item nao encontrado
 */
router.delete('/:id', async (req: Request, res: Response) => {
  try {
    const item = await itineraryItemsService.getItineraryItemById(req.params.id);
    if (!item) {
      return res.status(404).json({ error: 'Item nao encontrado' });
    }
    await itineraryItemsService.deleteItineraryItem(req.params.id);
    res.json({ message: 'Item eliminado com sucesso' });
  } catch (error) {
    console.error('Erro ao eliminar item:', error);
    res.status(400).json({ error: 'Erro ao eliminar item do itinerario' });
  }
});

/**
 * @swagger
 * /api/itinerary-items/reorder/{itineraryId}:
 *   put:
 *     summary: Reordenar items do itinerario
 *     tags: [Itinerary Items]
 *     parameters:
 *       - in: path
 *         name: itineraryId
 *         required: true
 *         schema:
 *           type: string
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - itemIds
 *             properties:
 *               itemIds:
 *                 type: array
 *                 items:
 *                   type: string
 *     responses:
 *       200:
 *         description: Items reordenados com sucesso
 */
router.put('/reorder/:itineraryId', async (req: Request, res: Response) => {
  try {
    const { itemIds } = req.body;
    await itineraryItemsService.reorderItems(req.params.itineraryId, itemIds);
    res.json({ message: 'Items reordenados com sucesso' });
  } catch (error) {
    console.error('Erro ao reordenar items:', error);
    res.status(400).json({ error: 'Erro ao reordenar items' });
  }
});

/**
 * @swagger
 * /api/itinerary-items/recalculate-distances/{itineraryId}:
 *   post:
 *     summary: Recalcular distancias entre pontos do itinerario
 *     tags: [Itinerary Items]
 *     parameters:
 *       - in: path
 *         name: itineraryId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Distancias recalculadas com sucesso
 */
router.post('/recalculate-distances/:itineraryId', async (req: Request, res: Response) => {
  try {
    await itineraryItemsService.recalculateDistances(req.params.itineraryId);
    res.json({ message: 'Distancias recalculadas com sucesso' });
  } catch (error) {
    console.error('Erro ao recalcular distancias:', error);
    res.status(500).json({ error: 'Erro ao recalcular distancias' });
  }
});

export const itineraryItemsController = router;