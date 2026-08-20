const { Router } = require('express');
const os = require('os');
const { stats: cacheStats } = require('../services/cache');

const router = Router();
const startTime = Date.now();

// Health check
router.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    uptime: Math.floor((Date.now() - startTime) / 1000),
    timestamp: new Date().toISOString(),
  });
});

// Detailed status
router.get('/api/status', (req, res) => {
  res.json({
    name: 'yt-music-server',
    version: '2.0.0',
    status: 'running',
    uptime: Math.floor((Date.now() - startTime) / 1000),
    uptimeHuman: formatUptime(Date.now() - startTime),
    cache: cacheStats(),
    system: {
      platform: os.platform(),
      arch: os.arch(),
      nodeVersion: process.version,
      memoryUsage: {
        rss: formatBytes(process.memoryUsage().rss),
        heapUsed: formatBytes(process.memoryUsage().heapUsed),
      },
    },
    timestamp: new Date().toISOString(),
  });
});

function formatUptime(ms) {
  const s = Math.floor(ms / 1000);
  const d = Math.floor(s / 86400);
  const h = Math.floor((s % 86400) / 3600);
  const m = Math.floor((s % 3600) / 60);
  return `${d}d ${h}h ${m}m`;
}

function formatBytes(bytes) {
  return `${(bytes / 1024 / 1024).toFixed(1)} MB`;
}

module.exports = router;
