const { Router } = require('express');
const youtube = require('../services/youtube');

const router = Router();

// Get direct audio URL (for Flutter app — does NOT proxy, returns URL)
router.get('/api/audio-url/:videoId', async (req, res, next) => {
  try {
    const { videoId } = req.params;

    if (!isValidVideoId(videoId)) {
      return res.status(400).json({ error: 'Invalid video ID' });
    }

    const resolved = await youtube.resolveAudioUrl(videoId);
    if (!resolved) {
      return res.status(404).json({ error: 'No audio URL found' });
    }

    res.json({
      url: resolved.url,
      isLive: resolved.isLive || false,
      isHls: resolved.isHls || false,
    });
  } catch (err) {
    next(err);
  }
});

// Batch pre-resolve URLs
// POST /api/audio-urls  Body: { videoIds: ["id1", "id2", ...] }
router.post('/api/audio-urls', async (req, res, next) => {
  try {
    const { videoIds } = req.body;

    if (!Array.isArray(videoIds) || videoIds.length === 0) {
      return res.status(400).json({ error: 'Missing or empty videoIds array' });
    }

    const BATCH_MAX = 3;
    const batch = videoIds.filter(isValidVideoId).slice(0, BATCH_MAX);
    const results = {};

    // Run sequentially to avoid CPU spikes on QNAP
    for (const videoId of batch) {
      try {
        results[videoId] = await youtube.resolveAudioUrl(videoId);
      } catch {
        results[videoId] = null;
      }
    }

    res.json({ urls: results });
  } catch (err) {
    next(err);
  }
});

// Heartbeat from device
router.post('/api/heartbeat', (req, res) => {
  const { deviceId, deviceName, platform } = req.body;
  console.log(`❤️ Heartbeat from ${deviceName || 'unknown'} (${platform || 'unknown'}) — ${deviceId || 'no-id'}`);
  res.json({ status: 'ok' });
});

function isValidVideoId(id) {
  return /^[a-zA-Z0-9_-]{6,16}$/.test(id);
}

module.exports = router;
