/**
 * Global error handler middleware
 */
function errorHandler(err, req, res, _next) {
  const status = err.status || err.statusCode || 500;
  const message = err.message || 'Internal Server Error';

  console.error(`[ERROR] ${req.method} ${req.path} — ${status}: ${message}`);
  if (process.env.NODE_ENV !== 'production') {
    console.error(err.stack);
  }

  res.status(status).json({
    error: message,
    status,
    path: req.path,
    timestamp: new Date().toISOString(),
  });
}

/**
 * 404 handler for unmatched routes
 */
function notFoundHandler(req, res) {
  res.status(404).json({
    error: 'Not Found',
    message: `Route ${req.method} ${req.path} not found`,
    availableEndpoints: {
      health: 'GET /health',
      status: 'GET /api/status',
      search: 'GET /api/search?q={query}',
      stream: 'GET /api/stream/:videoId',
      info: 'GET /api/info/:videoId',
      lyrics: 'GET /api/lyrics?q={song}',
      playlist: 'GET /api/playlist/:playlistId',
      download: 'GET /api/download/:videoId',
      trending: 'GET /api/trending',
      suggestions: 'GET /api/suggestions?q={query}',
      related: 'GET /api/related/:videoId',
    },
  });
}

module.exports = { errorHandler, notFoundHandler };
