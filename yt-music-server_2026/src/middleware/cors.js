const cors = require('cors');

const CORS_ORIGIN = process.env.CORS_ORIGIN || '*';

const corsMiddleware = cors({
  origin: CORS_ORIGIN === '*' ? true : CORS_ORIGIN.split(','),
  methods: ['GET', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Range', 'Authorization'],
  exposedHeaders: ['Content-Range', 'Content-Length', 'Content-Type', 'Accept-Ranges'],
  credentials: false,
  maxAge: 86400,
});

module.exports = corsMiddleware;
