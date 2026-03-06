import { Request, Response, NextFunction } from 'express';

interface RateLimitEntry {
  count: number;
  resetAt: number;
}

interface RateLimitConfig {
  windowMs: number;   // Janela de tempo em milissegundos
  maxRequests: number; // Máximo de requests por janela
  message?: string;    // Mensagem de erro personalizada
}

/**
 * In-memory rate limiter por IP.
 * Limpa entradas expiradas periodicamente para evitar memory leaks.
 */
function createRateLimiter(config: RateLimitConfig) {
  const store = new Map<string, RateLimitEntry>();

  // Limpeza periódica de entradas expiradas (a cada 60s)
  const cleanupInterval = setInterval(() => {
    const now = Date.now();
    for (const [key, entry] of store) {
      if (now >= entry.resetAt) {
        store.delete(key);
      }
    }
  }, 60_000);

  // Permitir que o processo termine sem ficar pendurado neste timer
  if (cleanupInterval.unref) {
    cleanupInterval.unref();
  }

  return (req: Request, res: Response, next: NextFunction): void => {
    // Extrair IP real (trust proxy deve estar ativo no Express)
    const ip =
      (req.headers['x-forwarded-for'] as string)?.split(',')[0]?.trim() ||
      req.ip ||
      req.socket.remoteAddress ||
      'unknown';

    const now = Date.now();
    const entry = store.get(ip);

    if (!entry || now >= entry.resetAt) {
      // Nova janela
      store.set(ip, { count: 1, resetAt: now + config.windowMs });
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
      res.status(429).json({
        error: config.message || 'Demasiadas requisições. Tenta novamente mais tarde.',
        retryAfter: retryAfterSec,
      });
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
  maxRequests: 100,
  message: 'Limite de requisições excedido. Tenta novamente dentro de 1 minuto.',
});

/**
 * Limite para autenticação: 10 requests por minuto por IP.
 * Protege contra brute-force de login/register.
 */
export const authRateLimit = createRateLimiter({
  windowMs: 60_000,     // 1 minuto
  maxRequests: 10,
  message: 'Demasiadas tentativas de autenticação. Tenta novamente dentro de 1 minuto.',
});

/**
 * Limite para endpoints de IA: 10 requests por minuto por IP.
 * Protege contra abuso de endpoints caros (OpenAI, etc).
 */
export const aiRateLimit = createRateLimiter({
  windowMs: 60_000,     // 1 minuto
  maxRequests: 10,
  message: 'Limite de requisições IA excedido. Tenta novamente dentro de 1 minuto.',
});
