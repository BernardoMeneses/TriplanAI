import { Request, Response, NextFunction } from 'express';

interface RateLimitEntry {
  count: number;
  resetAt: number;
}

interface BotPatternEntry {
  lastSignature: string;
  streak: number;
  lastSeenAt: number;
  blockedUntil: number;
}

interface RateLimitConfig {
  windowMs: number;   // Janela de tempo em milissegundos
  maxRequests: number; // Máximo de requests por janela
  // Anti-bot: limita repetições consecutivas da mesma ação
  sameActionWindowMs?: number;
  sameActionMaxStreak?: number;
  blockDurationMs?: number;
}

type RequestWithUser = Request & {
  user?: {
    id?: string;
  };
};

/**
 * In-memory rate limiter por IP.
 * Limpa entradas expiradas periodicamente para evitar memory leaks.
 */
function createRateLimiter(config: RateLimitConfig) {
  const store = new Map<string, RateLimitEntry>();
  const botStore = new Map<string, BotPatternEntry>();

  const sameActionWindowMs = config.sameActionWindowMs ?? 4_000;
  const sameActionMaxStreak = config.sameActionMaxStreak ?? 14;
  const blockDurationMs = config.blockDurationMs ?? 20_000;

  const hashString = (value: string): string => {
    let h = 0;
    for (let i = 0; i < value.length; i++) {
      h = (h << 5) - h + value.charCodeAt(i);
      h |= 0;
    }
    return String(h);
  };

  const safeBodySignature = (body: unknown): string => {
    try {
      if (body === null || body === undefined) return 'empty';
      if (typeof body === 'string') return hashString(body);
      return hashString(JSON.stringify(body));
    } catch {
      return 'unserializable';
    }
  };

  // Limpeza periódica de entradas expiradas (a cada 60s)
  const cleanupInterval = setInterval(() => {
    const now = Date.now();
    for (const [key, entry] of store) {
      if (now >= entry.resetAt) {
        store.delete(key);
      }
    }
    for (const [key, entry] of botStore) {
      if (entry.blockedUntil <= now && now - entry.lastSeenAt > sameActionWindowMs * 2) {
        botStore.delete(key);
      }
    }
  }, 60_000);

  // Permitir que o processo termine sem ficar pendurado neste timer
  if (cleanupInterval.unref) {
    cleanupInterval.unref();
  }

  return (req: Request, res: Response, next: NextFunction): void => {
    // Usa userId quando disponível; caso contrário, usa IP real.
    // Isto evita bloquear utilizadores diferentes atrás do mesmo proxy/NAT.
    const userId = (req as RequestWithUser).user?.id;
    const ip =
      (req.headers['x-forwarded-for'] as string)?.split(',')[0]?.trim() ||
      req.ip ||
      req.socket.remoteAddress ||
      'unknown';
    const key = userId ? `user:${userId}` : `ip:${ip}`;
    const actionSignature = `${req.method}:${req.baseUrl}${req.path}:${safeBodySignature(req.body)}`;

    const now = Date.now();

    // 1) Anti-bot por repetição consecutiva da mesma ação
    const botEntry = botStore.get(key);
    if (botEntry && now < botEntry.blockedUntil) {
      const retryAfterSec = Math.ceil((botEntry.blockedUntil - now) / 1000);
      res.setHeader('Retry-After', retryAfterSec);
      res.status(429).end();
      return;
    }

    if (!botEntry || now - botEntry.lastSeenAt > sameActionWindowMs) {
      botStore.set(key, {
        lastSignature: actionSignature,
        streak: 1,
        lastSeenAt: now,
        blockedUntil: 0,
      });
    } else {
      const isSameAction = botEntry.lastSignature === actionSignature;
      botEntry.streak = isSameAction ? botEntry.streak + 1 : 1;
      botEntry.lastSignature = actionSignature;
      botEntry.lastSeenAt = now;

      if (botEntry.streak >= sameActionMaxStreak) {
        botEntry.blockedUntil = now + blockDurationMs;
        const retryAfterSec = Math.ceil(blockDurationMs / 1000);
        res.setHeader('Retry-After', retryAfterSec);
        res.status(429).end();
        return;
      }
    }

    // 2) Limite volumétrico geral (mantido alto para não afetar edição normal)
    const entry = store.get(key);

    if (!entry || now >= entry.resetAt) {
      // Nova janela
      store.set(key, { count: 1, resetAt: now + config.windowMs });
      res.setHeader('X-RateLimit-Limit', config.maxRequests);
      res.setHeader('X-RateLimit-Remaining', config.maxRequests - 1);
      next();
      return;
    }

    entry.count++;

    if (entry.count > config.maxRequests) {
      const retryAfterMs = entry.resetAt - now;
      const retryAfterSec = Math.ceil(retryAfterMs / 1000);

      res.setHeader('Retry-After', retryAfterSec);
      res.setHeader('X-RateLimit-Limit', config.maxRequests);
      res.setHeader('X-RateLimit-Remaining', 0);
      res.status(429).end();
      return;
    }

    res.setHeader('X-RateLimit-Limit', config.maxRequests);
    res.setHeader('X-RateLimit-Remaining', config.maxRequests - entry.count);
    next();
  };
}

// ─── Rate limiters pré-configurados ─────────────────────────────

/**
 * Limite global: 100 requests por minuto por IP.
 * Protege contra scraping genérico e bots.
 */
export const globalRateLimit = createRateLimiter({
  windowMs: 60_000,     // 1 minuto
  maxRequests: 1_500,
  sameActionWindowMs: 4_000,
  sameActionMaxStreak: 14,
  blockDurationMs: 20_000,
});

/**
 * Limite para autenticação: 10 requests por minuto por IP.
 * Protege contra brute-force de login/register.
 */
export const authRateLimit = createRateLimiter({
  windowMs: 60_000,     // 1 minuto
  maxRequests: 10,
  sameActionWindowMs: 15_000,
  sameActionMaxStreak: 8,
  blockDurationMs: 60_000,
});

/**
 * Limite para endpoints de IA: 10 requests por minuto por IP.
 * Protege contra abuso de endpoints caros (OpenAI, etc).
 */
export const aiRateLimit = createRateLimiter({
  windowMs: 60_000,     // 1 minuto
  maxRequests: 10,
  sameActionWindowMs: 8_000,
  sameActionMaxStreak: 6,
  blockDurationMs: 45_000,
});
