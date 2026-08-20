const { Router } = require('express');
const fetch = require('node-fetch');
const youtube = require('../services/youtube');

const router = Router();

// Download audio as attachment
router.get('/api/download/:videoId', async (req, res, next) => {
  try {
    const { videoId } = req.params;
    const data = await youtube.getDownloadUrl(videoId);

    if (!data || !data.url) {
      return res.status(404).json({ error: 'Could not get download URL' });
    }

    // Sanitize filename
    const filename = `${(data.title || videoId).replace(/[^\w\s-]/g, '').trim()}.webm`;

    const audioRes = await fetch(data.url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Referer': 'https://www.youtube.com/',
      },
    });

    res.set('Content-Type', 'audio/webm');
    res.set('Content-Disposition', `attachment; filename="${filename}"`);
    if (audioRes.headers.get('content-length')) {
      res.set('Content-Length', audioRes.headers.get('content-length'));
    }

    audioRes.body.pipe(res);

    req.on('close', () => {
      if (audioRes.body && !audioRes.body.destroyed) {
        audioRes.body.destroy();
      }
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
