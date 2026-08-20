const { Router } = require('express');
const youtube = require('../services/youtube');

const router = Router();

// Search for music
router.get('/api/search', async (req, res, next) => {
  try {
    const { q, limit = 20 } = req.query;
    if (!q) {
      return res.status(400).json({ error: 'Missing required parameter: q' });
    }
    const results = await youtube.search(q, Math.min(parseInt(limit, 10) || 20, 50));
    res.json({
      query: q,
      count: results.length,
      results,
    });
  } catch (err) {
    next(err);
  }
});

// Trending music
router.get('/api/trending', async (req, res, next) => {
  try {
    const { region = 'TH' } = req.query;
    const results = await youtube.getTrending(region);
    res.json({
      region,
      count: results.length,
      results,
    });
  } catch (err) {
    next(err);
  }
});

// Search suggestions
router.get('/api/suggestions', async (req, res, next) => {
  try {
    const { q } = req.query;
    if (!q) {
      return res.status(400).json({ error: 'Missing required parameter: q' });
    }
    const suggestions = await youtube.getSuggestions(q);
    res.json({ query: q, suggestions });
  } catch (err) {
    next(err);
  }
});

// Related videos
router.get('/api/related/:videoId', async (req, res, next) => {
  try {
    const { videoId } = req.params;
    const results = await youtube.getRelated(videoId);
    res.json({
      videoId,
      count: results.length,
      results,
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
