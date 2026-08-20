const { Router } = require('express');
const { findLyrics } = require('../services/lyrics');

const router = Router();

// Search for lyrics
router.get('/api/lyrics', async (req, res, next) => {
  try {
    const { q } = req.query;
    if (!q) {
      return res.status(400).json({ error: 'Missing required parameter: q (song title + artist)' });
    }

    const lyrics = await findLyrics(q);
    if (!lyrics) {
      return res.status(404).json({
        error: 'Lyrics not found',
        query: q,
      });
    }

    res.json(lyrics);
  } catch (err) {
    next(err);
  }
});

module.exports = router;
