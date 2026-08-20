try { require('dotenv').config(); } catch (e) {}
const express = require('express');
const path = require('path');
const corsMiddleware = require('./middleware/cors');
const rateLimiter = require('./middleware/rateLimit');
const { errorHandler, notFoundHandler } = require('./middleware/errorHandler');

// Routes
const healthRoutes = require('./routes/health');
const searchRoutes = require('./routes/search');
const streamRoutes = require('./routes/stream');
const infoRoutes = require('./routes/info');
const lyricsRoutes = require('./routes/lyrics');
const playlistRoutes = require('./routes/playlist');
const downloadRoutes = require('./routes/download');
const appRoutes = require('./routes/app');
const speechRoutes = require('./routes/speech');

const app = express();
const PORT = parseInt(process.env.PORT || '3456', 10);

// ---- Middleware ----
app.use(corsMiddleware);
app.use(rateLimiter);
app.use(express.json({ limit: '15mb' }));

// Serve static files (APK downloads, version.json)
app.use(express.static(path.join(__dirname, '..', 'public')));

// Request logging
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = Date.now() - start;
    console.log(`[${new Date().toISOString()}] ${req.method} ${req.path} → ${res.statusCode} (${duration}ms)`);
  });
  next();
});

// ---- Routes ----
app.use(healthRoutes);
app.use(searchRoutes);
app.use(streamRoutes);
app.use(infoRoutes);
app.use(lyricsRoutes);
app.use(playlistRoutes);
app.use(downloadRoutes);
app.use(appRoutes);       // Flutter app: /api/audio-url, /api/audio-urls, /api/heartbeat
app.use(speechRoutes);    // Groq Whisper: /api/speech-to-text

// Root endpoint — API info
app.get('/', (req, res) => {
  res.json({
    name: 'yt-music-server',
    version: '2.0.0',
    description: 'YouTube Music Streaming API (M-PLAY Backend)',
    endpoints: {
      health: 'GET /health',
      status: 'GET /api/status',
      search: 'GET /api/search?q={query}&limit=20',
      trending: 'GET /api/trending?region=TH',
      suggestions: 'GET /api/suggestions?q={query}',
      related: 'GET /api/related/:videoId',
      stream: 'GET /api/stream/:videoId?quality=low|medium|high',
      info: 'GET /api/info/:videoId',
      lyrics: 'GET /api/lyrics?q={song+artist}',
      playlist: 'GET /api/playlist/:playlistId',
      download: 'GET /api/download/:videoId',
      audioUrl: 'GET /api/audio-url/:videoId',
      audioUrls: 'POST /api/audio-urls',
      heartbeat: 'POST /api/heartbeat',
      speechToText: 'POST /api/speech-to-text',
      versionCheck: 'GET /version.json',
    },
  });
});

// ---- Error handling ----
app.use(notFoundHandler);
app.use(errorHandler);

// ---- Start server ----
app.listen(PORT, '0.0.0.0', () => {
  console.log('');
  console.log('  ╔══════════════════════════════════════════╗');
  console.log('  ║     🎵 yt-music-server v2.0.0           ║');
  console.log(`  ║     🚀 Running on port ${PORT}             ║`);
  console.log('  ║     📡 M-PLAY Backend — Ready!           ║');
  console.log('  ╚══════════════════════════════════════════╝');
  console.log('');
  console.log(`  → Health:      http://localhost:${PORT}/health`);
  console.log(`  → Status:      http://localhost:${PORT}/api/status`);
  console.log(`  → Search:      http://localhost:${PORT}/api/search?q=lofi`);
  console.log(`  → Stream:      http://localhost:${PORT}/api/stream/{videoId}`);
  console.log(`  → Audio URL:   http://localhost:${PORT}/api/audio-url/{videoId}`);
  console.log(`  → Version:     http://localhost:${PORT}/version.json`);
  console.log('');
});

module.exports = app;
