const WINDOW_MS = parseInt(process.env.RATE_LIMIT_WINDOW_MS || '60000', 10);
const MAX_REQUESTS = parseInt(process.env.RATE_LIMIT_MAX || '100', 10);

let rateLimiter;

try {
  const rateLimit = require('express-rate-limit');
  rateLimiter = rateLimit({
    windowMs: WINDOW_MS,
    max: MAX_REQUESTS,
    standardHeaders: true,
    legacyHeaders: false,
    message: {
      error: 'Too many requests, please try again later.',
      retryAfter: Math.ceil(WINDOW_MS / 1000),
    },
    skip: (req) => req.path === '/health',
  });
} catch (e) {
  // Built-in in-memory rate limiter fallback
  const ipRequests = new Map();

  // Cleanup old entries every minute
  setInterval(() => {
    const now = Date.now();
    for (const [ip, data] of ipRequests.entries()) {
      if (now - data.startTime > WINDOW_MS) {
        ipRequests.delete(ip);
      }
    }
  }, WINDOW_MS);

  rateLimiter = (req, res, next) => {
    if (req.path === '/health') return next();

    const ip = req.ip || req.connection.remoteAddress || 'unknown';
    const now = Date.now();
    const current = ipRequests.get(ip) || { count: 0, startTime: now };

    if (now - current.startTime > WINDOW_MS) {
      current.count = 1;
      current.startTime = now;
    } else {
      current.count++;
    }

    ipRequests.set(ip, current);

    if (current.count > MAX_REQUESTS) {
      return res.status(429).json({
        error: 'Too many requests, please try again later.',
        retryAfter: Math.ceil(WINDOW_MS / 1000),
      });
    }

    next();
  };
}

module.exports = rateLimiter;
