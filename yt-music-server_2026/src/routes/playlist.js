const { Router } = require('express');
const youtube = require('../services/youtube');

const router = Router();

// Get playlist items
router.get('/api/playlist/:playlistId', async (req, res, next) => {
  try {
    const { playlistId } = req.params;
    const playlist = await youtube.getPlaylist(playlistId);
    res.json(playlist);
  } catch (err) {
    next(err);
  }
});

module.exports = router;
