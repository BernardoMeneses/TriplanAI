import express, { Express, Request, Response, NextFunction } from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import swaggerUi from 'swagger-ui-express';
import path from 'path';
import http from 'http';
import { setupWebSocket } from './websocket';

// Load environment variables first
dotenv.config();

// Config
import { swaggerSpec } from './config/swagger';
import { testConnection, query } from './config/database';

// Middleware
import { authenticate } from './middlewares';
import { globalRateLimit, authRateLimit, aiRateLimit } from './middlewares';

// Controllers
import { authController } from './modules/auth';
import { tripsController } from './modules/trips';
import { itinerariesController} from './modules/iteneraries';
import { placesController } from './modules/places';
import { routesController } from './modules/routes';
import { mapsController } from './modules/maps';
import { aiController } from './modules/ai';
import { favoritesController } from './modules/favorites';
import { premiumController } from './modules/premium';
import { itineraryItemsController } from './modules/iteneraries/itinerary_items.controller';
import { notesController } from './modules/notes';

const app: Express = express();
const PORT = Number(process.env.PORT) || 3000;

// Trust proxy (CapRover / nginx) para obter IP real do cliente
app.set('trust proxy', 1);

// Middleware
app.use(cors());
app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: true, limit: '1mb' }));

// Rate limiting global — aplica-se a TODOS os endpoints
app.use(globalRateLimit);

// Serve static files for password reset and email verification pages
// In Docker, public folder is in the root alongside dist
const publicPath = path.join(__dirname, '../public');
app.use('/auth', express.static(publicPath));
// Public delete-account page (Play Console link expects a public URL)
app.get('/delete-account', (_req, res) => {
  res.sendFile(path.join(publicPath, 'delete-account.html'));
});
// Also expose the raw html path for direct links used in emails
app.get('/delete-account.html', (_req, res) => {
  res.sendFile(path.join(publicPath, 'delete-account.html'));
});

// Swagger Documentation
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec, {
  customCss: '.swagger-ui .topbar { display: none }',
  customSiteTitle: 'TriplanAI API Documentation',
}));

// Swagger JSON endpoint
app.get('/api-docs.json', (_req, res) => {
  res.setHeader('Content-Type', 'application/json');
  res.send(swaggerSpec);
});

// Health Check
app.get('/health', async (_req: Request, res: Response) => {
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

// Public Routes (com rate limit extra para auth)
app.use('/api/auth', authRateLimit, authController);

// Protected Routes
app.use('/api/trips', authenticate, tripsController);
app.use('/api/itineraries', authenticate, itinerariesController);
app.use('/api/places', authenticate, placesController);
app.use('/api/routes', authenticate, routesController);
app.use('/api/maps', authenticate, mapsController);
app.use('/api/ai', authenticate, aiRateLimit, aiController);
app.use('/api/favorites', authenticate, favoritesController);
app.use('/api/notes', authenticate, notesController);
app.use('/api/itinerary-items', authenticate, itineraryItemsController);

// Premium routes (webhook não precisa de autenticação)
app.use('/api/premium', (req, res, next) => {
  // Webhook do Adapty não precisa autenticação
  if (req.path === '/adapty-webhook') {
    return next();
  }
  // Outras rotas precisam autenticação
  return authenticate(req, res, next);
}, premiumController);

// 404 Handler
app.use((_req, res) => {
  res.status(404).json({ error: 'Endpoint não encontrado' });
});

// Error Handler
app.use((err: Error, _req: Request, res: Response, _next: NextFunction) => {
  console.error(err);
  res.status(500).json({ error: 'Erro interno do servidor' });
});

// 🚀 START SERVER IMMEDIATELY (CapRover-friendly)
const server = http.createServer(app);
setupWebSocket(server);
server.listen(PORT, '0.0.0.0', () => {
  console.log(`
╔═══════════════════════════════════════════════════════════╗
║ 🌍 TriplanAI API                                         ║
║ Server running on port ${PORT}                            ║
║ Swagger: /api-docs                                       ║
╚═══════════════════════════════════════════════════════════╝
  `);
});

// 🔌 Database connection in background (NON-BLOCKING)
testConnection()
  .then(() => console.log('✅ Database connected'))
  .catch(err => console.error('❌ Database connection failed', err));

export default app;
