import { Server, WebSocket } from 'ws';
import jwt from 'jsonwebtoken';
import { query } from './config/database';

const jwtSecret = process.env.JWT_SECRET;

if (!jwtSecret) {
  throw new Error('JWT_SECRET must be configured');
}

const JWT_SECRET: string = jwtSecret;

type AuthenticatedSocket = WebSocket & {
  userId?: string;
  subscriptions?: Set<string>;
  connectionToken?: string | null;
};

let wss: Server | null = null;
const clientsByItinerary: Record<string, Set<AuthenticatedSocket>> = {};

function getConnectionToken(reqUrl?: string, host?: string): string | null {
  if (!reqUrl) return null;

  try {
    const url = new URL(reqUrl, `http://${host || 'localhost'}`);
    return url.searchParams.get('token');
  } catch {
    return null;
  }
}

async function authenticateToken(token: string): Promise<string | null> {
  try {
    const decoded = jwt.verify(token, JWT_SECRET) as { userId?: string };
    const userId = decoded?.userId;

    if (!userId) {
      return null;
    }

    const result = await query<{ id: string }>(
      'SELECT id FROM users WHERE id = $1 AND is_active = true',
      [userId],
    );

    if (result.rows.length === 0) {
      return null;
    }

    return userId;
  } catch {
    return null;
  }
}

async function ensureAuthenticatedSocket(
  ws: AuthenticatedSocket,
  token?: string | null,
): Promise<string | null> {
  if (ws.userId) {
    return ws.userId;
  }

  const candidateToken = token || ws.connectionToken;
  if (!candidateToken) {
    return null;
  }

  const userId = await authenticateToken(candidateToken);
  if (!userId) {
    return null;
  }

  ws.userId = userId;
  return userId;
}

async function canAccessItinerary(
  userId: string,
  itineraryId: string,
): Promise<boolean> {
  const result = await query(
    `SELECT 1
     FROM itineraries i
     INNER JOIN trips t ON t.id = i.trip_id
     WHERE i.id = $1
       AND (
         t.user_id = $2
         OR EXISTS (
           SELECT 1
           FROM trip_members tm
           WHERE tm.trip_id = t.id
             AND tm.user_id = $2
         )
       )
     LIMIT 1`,
    [itineraryId, userId],
  );

  return result.rows.length > 0;
}

function unsubscribeSocket(ws: AuthenticatedSocket): void {
  for (const key of ws.subscriptions || []) {
    clientsByItinerary[key]?.delete(ws);
    if (clientsByItinerary[key]?.size === 0) {
      delete clientsByItinerary[key];
    }
  }

  ws.subscriptions?.clear();
}

export function setupWebSocket(server: any) {
  wss = new Server({ server });

  wss.on('connection', (rawSocket, req) => {
    const ws = rawSocket as AuthenticatedSocket;
    ws.subscriptions = new Set<string>();
    ws.connectionToken = getConnectionToken(req.url, req.headers.host);

    ws.on('message', async (message) => {
      try {
        const rawMessage = Buffer.isBuffer(message)
          ? message.toString('utf8')
          : String(message);
        const data = JSON.parse(rawMessage);

        if (data.type === 'auth' && typeof data.token === 'string') {
          const userId = await ensureAuthenticatedSocket(ws, data.token);
          if (!userId) {
            ws.send(JSON.stringify({ type: 'error', code: 'UNAUTHORIZED' }));
            return;
          }

          ws.send(JSON.stringify({ type: 'auth_ok' }));
          return;
        }

        if (
          data.type === 'subscribe' &&
          typeof data.itineraryId === 'string' &&
          Number.isInteger(Number(data.dayNumber))
        ) {
          const userId = await ensureAuthenticatedSocket(
            ws,
            typeof data.token === 'string' ? data.token : undefined,
          );

          if (!userId) {
            ws.send(JSON.stringify({ type: 'error', code: 'UNAUTHORIZED' }));
            return;
          }

          const itineraryId = data.itineraryId;
          const dayNumber = Number(data.dayNumber);

          if (dayNumber < 1) {
            ws.send(JSON.stringify({ type: 'error', code: 'INVALID_DAY' }));
            return;
          }

          const authorized = await canAccessItinerary(userId, itineraryId);
          if (!authorized) {
            ws.send(JSON.stringify({ type: 'error', code: 'FORBIDDEN' }));
            return;
          }

          const key = `${itineraryId}:${dayNumber}`;
          if (!clientsByItinerary[key]) {
            clientsByItinerary[key] = new Set();
          }

          clientsByItinerary[key].add(ws);
          ws.subscriptions?.add(key);

          ws.send(JSON.stringify({ type: 'subscribed', itineraryId, dayNumber }));
        }
      } catch {
        ws.send(JSON.stringify({ type: 'error', code: 'INVALID_PAYLOAD' }));
      }
    });

    ws.on('close', () => {
      unsubscribeSocket(ws);
    });
  });
}

export function emitItineraryUpdate(itineraryId: string, dayNumber: number) {
  const key = `${itineraryId}:${dayNumber}`;
  const clients = clientsByItinerary[key];

  if (!clients) {
    return;
  }

  for (const ws of clients) {
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify({ type: 'itinerary_update', itineraryId, dayNumber }));
    }
  }
}
