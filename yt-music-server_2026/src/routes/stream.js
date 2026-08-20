const { Router } = require('express');
const https = require('https');
const http = require('http');
const youtube = require('../services/youtube');

const router = Router();
const MAX_REDIRECTS = 5;

// ============================================
// API: Stream audio (proxied with Range & HLS support)
// GET /api/stream/:videoId
// ============================================
router.get('/api/stream/:videoId', async (req, res, next) => {
  try {
    const { videoId } = req.params;

    if (!isValidVideoId(videoId)) {
      return res.status(400).json({ error: 'Invalid video ID' });
    }

    console.log(`🎵 Streaming request: ${videoId}`);

    const resolved = await youtube.resolveAudioUrl(videoId);
    if (!resolved || !resolved.url) {
      return res.status(404).json({ error: 'No audio stream found' });
    }

    const { url: audioUrl, isLive, isHls } = resolved;
    console.log(`🔗 Stream URL resolved for: ${videoId} (isLive=${isLive}, isHls=${isHls})`);

    // Live/HLS stream: proxy manifest with Apple MPEGURL content type for ExoPlayer
    if (isLive || isHls) {
      console.log(`📡 Live stream — proxying HLS manifest: ${videoId}`);
      const parsedHlsUrl = new URL(audioUrl);
      const hlsProtocol = parsedHlsUrl.protocol === 'https:' ? https : http;
      const hlsReq = hlsProtocol.get(
        audioUrl,
        {
          headers: {
            'Accept-Encoding': 'identity',
          },
        },
        (hlsRes) => {
          if (!res.headersSent) {
            res.setHeader('Content-Type', 'application/vnd.apple.mpegurl');
            res.setHeader('Access-Control-Allow-Origin', '*');
            res.setHeader('Cache-Control', 'no-cache');
            res.status(200);
            hlsRes.pipe(res);
          }
        }
      );
      hlsReq.on('error', (err) => {
        console.error('HLS proxy error:', err.message);
        if (!res.headersSent) res.status(500).json({ error: 'HLS proxy failed' });
      });
      req.on('close', () => hlsReq.destroy());
      return;
    }

    // Regular audio stream proxy (with redirect following & Range headers)
    const proxyStream = (url, depth = 0) => {
      if (depth > MAX_REDIRECTS) {
        if (!res.headersSent) res.status(500).json({ error: 'Too many redirects' });
        return;
      }

      const parsedUrl = new URL(url);
      const protocol = parsedUrl.protocol === 'https:' ? https : http;

      // DO NOT send desktop Chrome UA because YouTube signatures are tied to the extractor client (ANDROID_VR)
      const upstreamHeaders = {
        'Accept-Encoding': 'identity',
        'Connection': 'keep-alive',
      };

      // Always send Range header to YouTube (default to bytes=0- if client didn't specify one)
      // because YouTube DASH/audio streams strictly return 403 Forbidden without Range header
      upstreamHeaders['Range'] = req.headers.range || 'bytes=0-';

      // Forward client User-Agent if present
      if (req.headers['user-agent']) {
        upstreamHeaders['User-Agent'] = req.headers['user-agent'];
      }

      const proxyReq = protocol.get(url, { headers: upstreamHeaders }, (proxyRes) => {
        // Follow redirects
        if (proxyRes.statusCode >= 300 && proxyRes.statusCode < 400 && proxyRes.headers.location) {
          console.log(`↪️ Stream redirect [${depth}] → ${proxyRes.headers.location.slice(0, 60)}...`);
          proxyStream(proxyRes.headers.location, depth + 1);
          return;
        }

        const responseHeaders = {
          'Content-Type': proxyRes.headers['content-type'] || 'audio/mp4',
          'Accept-Ranges': 'bytes',
          'Cache-Control': 'no-cache',
          'Access-Control-Allow-Origin': '*',
          'Connection': 'keep-alive',
        };

        if (proxyRes.headers['content-length']) {
          responseHeaders['Content-Length'] = proxyRes.headers['content-length'];
        }
        if (proxyRes.headers['content-range']) {
          responseHeaders['Content-Range'] = proxyRes.headers['content-range'];
        }

        res.writeHead(proxyRes.statusCode, responseHeaders);
        proxyRes.pipe(res);
      });

      proxyReq.on('error', (error) => {
        console.error('Proxy error:', error.message);
        if (!res.headersSent) res.status(500).json({ error: 'Stream failed' });
      });

      req.on('close', () => proxyReq.destroy());
    };

    proxyStream(audioUrl);
  } catch (err) {
    next(err);
  }
});

function isValidVideoId(id) {
  return /^[a-zA-Z0-9_-]{6,16}$/.test(id);
}

module.exports = router;
