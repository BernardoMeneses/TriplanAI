import { Router, Request, Response } from 'express';
import { tripsService } from './trips.service';

const router = Router();

/**
 * @swagger
 * /api/trips:
 *   post:
 *     summary: Criar nova viagem
 *     tags: [Trips]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - title
 *               - destination_city
 *               - destination_country
 *               - start_date
 *               - end_date
 *             properties:
 *               title:
 *                 type: string
 *               description:
 *                 type: string
 *               destination_city:
 *                 type: string
 *               destination_country:
 *                 type: string
 *               start_date:
 *                 type: string
 *                 format: date
 *               end_date:
 *                 type: string
 *                 format: date
 *               budget:
 *                 type: number
 *               currency:
 *                 type: string
 *                 default: EUR
 *               trip_type:
 *                 type: string
 *                 enum: [leisure, business, adventure, cultural]
 *               number_of_travelers:
 *                 type: integer
 *                 default: 1
 *     responses:
 *       201:
 *         description: Viagem criada com sucesso
 *       400:
 *         description: Dados inválidos
 *       401:
 *         description: Não autenticado
 */
router.post('/', async (req: Request, res: Response) => {
  try {
    const userId = req.user!.id;
    const trip = await tripsService.createTrip(userId, req.body);
    res.status(201).json(trip);
  } catch (error) {
    console.error('Erro ao criar viagem:', error);
    res.status(400).json({ error: 'Erro ao criar viagem' });
  }
});

/**
 * @swagger
 * /api/trips:
 *   get:
 *     summary: Listar viagens do utilizador autenticado
 *     tags: [Trips]
 *     responses:
 *       200:
 *         description: Lista de viagens
 *       401:
 *         description: Não autenticado
 */
router.get('/', async (req: Request, res: Response) => {
  try {
    const userId = req.user!.id;
    const trips = await tripsService.getTripsByUser(userId);
    res.json(trips);
  } catch (error) {
    res.status(400).json({ error: 'Erro ao listar viagens' });
  }
});

/**
 * @swagger
 * /api/trips/{id}:
 *   get:
 *     summary: Obter viagem por ID
 *     tags: [Trips]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Detalhes da viagem
 *       404:
 *         description: Viagem não encontrada
 */
router.get('/:id', async (req: Request, res: Response) => {
  try {
    const trip = await tripsService.getTripById(req.params.id);
    if (!trip) {
      return res.status(404).json({ error: 'Viagem não encontrada' });
    }
    res.json(trip);
  } catch (error) {
    res.status(400).json({ error: 'Erro ao obter viagem' });
  }
});

/**
 * @swagger
 * /api/trips/{id}:
 *   put:
 *     summary: Atualizar viagem
 *     tags: [Trips]
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
 *             properties:
 *               name:
 *                 type: string
 *               description:
 *                 type: string
 *               destination:
 *                 type: string
 *               startDate:
 *                 type: string
 *                 format: date
 *               endDate:
 *                 type: string
 *                 format: date
 *     responses:
 *       200:
 *         description: Viagem atualizada
 *       404:
 *         description: Viagem não encontrada
 */
router.put('/:id', async (req: Request, res: Response) => {
  try {
    const trip = await tripsService.updateTrip(req.params.id, req.body);
    if (!trip) {
      return res.status(404).json({ error: 'Viagem não encontrada' });
    }
    res.json(trip);
  } catch (error) {
    res.status(400).json({ error: 'Erro ao atualizar viagem' });
  }
});

/**
 * @swagger
 * /api/trips/{id}:
 *   delete:
 *     summary: Eliminar viagem
 *     tags: [Trips]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Viagem eliminada
 *       404:
 *         description: Viagem não encontrada
 */
router.delete('/:id', async (req: Request, res: Response) => {
  try {
    const deleted = await tripsService.deleteTrip(req.params.id);
    if (!deleted) {
      return res.status(404).json({ error: 'Viagem não encontrada' });
    }
    res.json({ message: 'Viagem eliminada com sucesso' });
  } catch (error) {
    res.status(400).json({ error: 'Erro ao eliminar viagem' });
  }
});

export const tripsController = router;
