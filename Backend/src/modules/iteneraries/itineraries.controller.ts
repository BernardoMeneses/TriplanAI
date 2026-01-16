import { Router, Request, Response } from 'express';
import { itinerariesService } from './itineraries.service';

const router = Router();

/**
 * @swagger
 * /api/itineraries:
 *   post:
 *     summary: Criar novo itinerário
 *     tags: [Itineraries]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - tripId
 *               - day
 *               - date
 *             properties:
 *               tripId:
 *                 type: string
 *               day:
 *                 type: number
 *               date:
 *                 type: string
 *                 format: date
 *               activities:
 *                 type: array
 *                 items:
 *                   type: object
 *     responses:
 *       201:
 *         description: Itinerário criado com sucesso
 */
router.post('/', async (req: Request, res: Response) => {
  try {
    const { tripId, ...itineraryData } = req.body;
    const itinerary = await itinerariesService.createItinerary(tripId, itineraryData);
    res.status(201).json(itinerary);
  } catch (error) {
    res.status(400).json({ error: 'Erro ao criar itinerário' });
  }
});

/**
 * @swagger
 * /api/itineraries/trip/{tripId}:
 *   get:
 *     summary: Listar itinerários de uma viagem
 *     tags: [Itineraries]
 *     parameters:
 *       - in: path
 *         name: tripId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Lista de itinerários
 */
router.get('/trip/:tripId', async (req: Request, res: Response) => {
  try {
    const itineraries = await itinerariesService.getItinerariesByTrip(req.params.tripId);
    res.json(itineraries);
  } catch (error) {
    res.status(400).json({ error: 'Erro ao listar itinerários' });
  }
});

/**
 * @swagger
 * /api/itineraries/{id}:
 *   get:
 *     summary: Obter itinerário por ID
 *     tags: [Itineraries]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Detalhes do itinerário
 *       404:
 *         description: Itinerário não encontrado
 */
router.get('/:id', async (req: Request, res: Response) => {
  try {
    const itinerary = await itinerariesService.getItineraryById(req.params.id);
    if (!itinerary) {
      return res.status(404).json({ error: 'Itinerário não encontrado' });
    }
    res.json(itinerary);
  } catch (error) {
    res.status(400).json({ error: 'Erro ao obter itinerário' });
  }
});

/**
 * @swagger
 * /api/itineraries/{id}:
 *   put:
 *     summary: Atualizar itinerário
 *     tags: [Itineraries]
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
 *         description: Itinerário atualizado
 */
router.put('/:id', async (req: Request, res: Response) => {
  try {
    const itinerary = await itinerariesService.updateItinerary(req.params.id, req.body);
    if (!itinerary) {
      return res.status(404).json({ error: 'Itinerário não encontrado' });
    }
    res.json(itinerary);
  } catch (error) {
    res.status(400).json({ error: 'Erro ao atualizar itinerário' });
  }
});

/**
 * @swagger
 * /api/itineraries/{id}:
 *   delete:
 *     summary: Eliminar itinerário
 *     tags: [Itineraries]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Itinerário eliminado
 */
router.delete('/:id', async (req: Request, res: Response) => {
  try {
    const deleted = await itinerariesService.deleteItinerary(req.params.id);
    if (!deleted) {
      return res.status(404).json({ error: 'Itinerário não encontrado' });
    }
    res.json({ message: 'Itinerário eliminado com sucesso' });
  } catch (error) {
    res.status(400).json({ error: 'Erro ao eliminar itinerário' });
  }
});

/**
 * @swagger
 * /api/itineraries/{id}/activities:
 *   post:
 *     summary: Adicionar atividade ao itinerário
 *     tags: [Itineraries]
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
 *             required:
 *               - name
 *               - startTime
 *               - endTime
 *             properties:
 *               name:
 *                 type: string
 *               description:
 *                 type: string
 *               startTime:
 *                 type: string
 *               endTime:
 *                 type: string
 *               placeId:
 *                 type: string
 *     responses:
 *       200:
 *         description: Atividade adicionada
 */
router.post('/:id/items', async (req: Request, res: Response) => {
  try {
    const item = await itinerariesService.addItem(req.params.id, req.body);
    res.status(201).json(item);
  } catch (error) {
    console.error('Erro ao adicionar item:', error);
    res.status(400).json({ error: 'Erro ao adicionar item ao itinerário' });
  }
});

/**
 * @swagger
 * /api/itineraries/trip/{tripId}/day/{dayNumber}:
 *   get:
 *     summary: Buscar ou criar itinerário para um dia específico
 *     tags: [Itineraries]
 *     parameters:
 *       - in: path
 *         name: tripId
 *         required: true
 *         schema:
 *           type: string
 *       - in: path
 *         name: dayNumber
 *         required: true
 *         schema:
 *           type: integer
 *     responses:
 *       200:
 *         description: Itinerário retornado
 */
router.get('/trip/:tripId/day/:dayNumber', async (req: Request, res: Response) => {
  try {
    const { tripId, dayNumber } = req.params;
    const itinerary = await itinerariesService.getOrCreateItineraryByDay(tripId, parseInt(dayNumber));
    res.json(itinerary);
  } catch (error) {
    console.error('Erro ao buscar/criar itinerário:', error);
    res.status(500).json({ error: 'Erro ao buscar itinerário' });
  }
});

export const itinerariesController = router;
