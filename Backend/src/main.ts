import express, { Express, Request, Response, NextFunction } from 'express';
import cors, { CorsOptions } from 'cors';
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
import { tripsService } from './modules/trips';
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
const TRIP_RETENTION_CLEANUP_ENABLED =
  (process.env.TRIP_RETENTION_CLEANUP_ENABLED || 'true').toLowerCase() !== 'false';
const TRIP_RETENTION_CLEANUP_INTERVAL_MS = Number(
  process.env.TRIP_RETENTION_CLEANUP_INTERVAL_MS || 6 * 60 * 60 * 1000,
);

function startTripRetentionCleanupJob(): void {
  if (!TRIP_RETENTION_CLEANUP_ENABLED) {
    console.log('ℹ️ Trip retention cleanup job disabled by env');
    return;
  }

  const runCleanup = async () => {
    try {
      const result = await tripsService.cleanupExpiredPastTripsForAllUsers();
      if (result.deletedTrips > 0) {
        console.log(
          `🧹 Trip retention cleanup: deleted=${result.deletedTrips} (free=${result.deletedFreeTrips}, basic=${result.deletedBasicTrips})`,
        );
      }
    } catch (error) {
      console.error('❌ Trip retention cleanup job failed:', error);
    }
  };

  // Run once at startup and then periodically.
  void runCleanup();
  const cleanupInterval = setInterval(() => {
    void runCleanup();
  }, TRIP_RETENTION_CLEANUP_INTERVAL_MS);

  if (cleanupInterval.unref) {
    cleanupInterval.unref();
  }
}

function normalizeOrigin(origin: string): string {
  const trimmed = origin.trim();
  if (!trimmed) {
    return '';
  }

  try {
    return new URL(trimmed).origin;
  } catch {
    return trimmed.replace(/\/+$/, '');
  }
}

function parseAllowedCorsOrigins(): string[] {
  const keys = ['CORS_ALLOWED_ORIGINS', 'ALLOWED_ORIGINS', 'FRONTEND_URL'];
  const origins = new Set<string>();

  for (const key of keys) {
    const rawValue = process.env[key];
    if (!rawValue) continue;

    const parsedOrigins = rawValue
      .split(',')
      .map((origin) => normalizeOrigin(origin))
      .filter((origin) => origin.length > 0);

    for (const origin of parsedOrigins) {
      origins.add(origin);
    }
  }

  return [...origins];
}

const configuredCorsOrigins = parseAllowedCorsOrigins();
const isProduction = (process.env.NODE_ENV || '').toLowerCase() === 'production';
const defaultDevelopmentOrigins = [
  'http://localhost:3000',
  'http://127.0.0.1:3000',
  'http://localhost:5173',
  'http://127.0.0.1:5173',
  'http://localhost:8080',
  'http://127.0.0.1:8080',
];

if (isProduction && configuredCorsOrigins.length === 0) {
  throw new Error(
    'CORS allowlist is required in production. Configure CORS_ALLOWED_ORIGINS, ALLOWED_ORIGINS, or FRONTEND_URL.',
  );
}

const allowedCorsOrigins =
  configuredCorsOrigins.length > 0
    ? configuredCorsOrigins
    : defaultDevelopmentOrigins;

const corsOptions: CorsOptions = {
  origin: (origin, callback) => {
    if (!origin) {
      callback(null, true);
      return;
    }

    if (allowedCorsOrigins.includes(normalizeOrigin(origin))) {
      callback(null, true);
      return;
    }

    callback(new Error('Not allowed by CORS'));
  },
  methods: ['GET', 'HEAD', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Authorization', 'Content-Type', 'Accept'],
  optionsSuccessStatus: 204,
};

// Trust proxy (CapRover / nginx) para obter IP real do cliente
app.set('trust proxy', 1);

// Middleware
app.use(cors(corsOptions));
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
  if (err.message === 'Not allowed by CORS') {
    return res.status(403).json({ error: 'Origin not allowed' });
  }
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

  startTripRetentionCleanupJob();
});

// 🔌 Database connection in background (NON-BLOCKING)
testConnection()
  .then(() => console.log('✅ Database connected'))
  .catch(err => console.error('❌ Database connection failed', err));

export default app;
