const { Router } = require('express');
const youtube = require('../services/youtube');

const router = Router();

// Get video info
router.get('/api/info/:videoId', async (req, res, next) => {
  try {
    const { videoId } = req.params;
    const info = await youtube.getInfo(videoId);
    res.json(info);
  } catch (err) {
    next(err);
  }
});

module.exports = router;
