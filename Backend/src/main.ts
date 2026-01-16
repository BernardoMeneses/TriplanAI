import express, { Express, Request, Response, NextFunction } from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import swaggerUi from 'swagger-ui-express';

// Load environment variables first
dotenv.config();

// Config
import { swaggerSpec } from './config/swagger';
import { testConnection, query } from './config/database';

// Middleware
import { authenticate } from './middlewares';

// Controllers
import { authController } from './modules/auth';
import { tripsController } from './modules/trips';
import { itinerariesController, ItineraryItemsController } from './modules/iteneraries';
import { placesController } from './modules/places';
import { routesController } from './modules/routes';
import { mapsController } from './modules/maps';
import { aiController } from './modules/ai';

const itineraryItemsController = new ItineraryItemsController();

const app: Express = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Swagger Documentation
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec, {
  customCss: '.swagger-ui .topbar { display: none }',
  customSiteTitle: 'TriplanAI API Documentation',
}));

// Swagger JSON endpoint
app.get('/api-docs.json', (req: Request, res: Response) => {
  res.setHeader('Content-Type', 'application/json');
  res.send(swaggerSpec);
});

// Health Check
/**
 * @swagger
 * /health:
 *   get:
 *     summary: Verificar estado da API
 *     tags: [Health]
 *     security: []
 *     responses:
 *       200:
 *         description: API está a funcionar
 */
app.get('/health', async (req: Request, res: Response) => {
  let dbStatus = 'disconnected';
  try {
    await query('SELECT 1');
    dbStatus = 'connected';
  } catch {
    dbStatus = 'disconnected';
  }
  
  res.json({ 
    status: 'ok', 
    timestamp: new Date().toISOString(),
    version: '1.0.0',
    database: dbStatus
  });
});

// Public Routes (no authentication required)
app.use('/api/auth', authController);

// Protected Routes (authentication required)
app.use('/api/trips', authenticate, tripsController);
app.use('/api/itineraries', authenticate, itinerariesController);
app.use('/api/places', authenticate, placesController);
app.use('/api/routes', authenticate, routesController);
app.use('/api/maps', authenticate, mapsController);
app.use('/api/ai', authenticate, aiController);

// Itinerary Items Routes
app.post('/api/itinerary-items', authenticate, (req, res) => itineraryItemsController.createItem(req, res));
app.get('/api/itinerary-items/itinerary/:itineraryId', authenticate, (req, res) => itineraryItemsController.getItemsByDay(req, res));
app.get('/api/itinerary-items/:id', authenticate, (req, res) => itineraryItemsController.getItemById(req, res));
app.put('/api/itinerary-items/:id', authenticate, (req, res) => itineraryItemsController.updateItem(req, res));
app.delete('/api/itinerary-items/:id', authenticate, (req, res) => itineraryItemsController.deleteItem(req, res));
app.post('/api/itinerary-items/reorder/:itineraryId', authenticate, (req, res) => itineraryItemsController.reorderItems(req, res));

// 404 Handler
app.use((req: Request, res: Response) => {
  res.status(404).json({ error: 'Endpoint não encontrado' });
});

// Error Handler
app.use((err: Error, req: Request, res: Response, next: NextFunction) => {
  console.error(err.stack);
  res.status(500).json({ error: 'Erro interno do servidor' });
});

// Start server
const startServer = async () => {
  // Test database connection
  const dbConnected = await testConnection();
  
  app.listen(PORT, () => {
    console.log(`
  ╔═══════════════════════════════════════════════════════════╗
  ║                                                           ║
  ║   🌍 TriplanAI API                                        ║
  ║                                                           ║
  ║   Server running at: http://localhost:${PORT}               ║
  ║   Swagger docs at:   http://localhost:${PORT}/api-docs      ║
  ║   Database:          ${dbConnected ? '✅ Connected' : '❌ Disconnected'}                     ║
  ║                                                           ║
  ╚═══════════════════════════════════════════════════════════╝
    `);
  });
};

startServer();

export default app;
