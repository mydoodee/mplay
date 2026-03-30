const express = require('express');
const cors = require('cors');
const { execFile, spawn } = require('child_process');
const path = require('path');
const https = require('https');
const http = require('http');
const urlModule = require('url');

const app = express();
const PORT = 3456;

// yt-dlp executable path
const YT_DLP_PATH = process.platform === 'win32' 
  ? path.join(process.env.APPDATA || '', 'Python', 'Python313', 'Scripts', 'yt-dlp.exe')
  : 'yt-dlp';

// ============================================
// 🎵 URL Cache — ลด latency ในการ resolve ซ้ำ
// Cache URL ไว้ 25 นาที (YouTube URL หมดอายุ ~6 ชม.)
// ============================================
const urlCache = new Map();
const CACHE_TTL = 25 * 60 * 1000; // 25 minutes

function getCachedUrl(videoId) {
  const cached = urlCache.get(videoId);
  if (cached && Date.now() - cached.timestamp < CACHE_TTL) {
    return cached.url;
  }
  urlCache.delete(videoId);
  return null;
}

function setCachedUrl(videoId, url) {
  urlCache.set(videoId, { url, timestamp: Date.now() });
  
  // Cleanup old entries (keep max 200)
  if (urlCache.size > 200) {
    const oldest = urlCache.keys().next().value;
    urlCache.delete(oldest);
  }
}

// Middleware
app.use(cors());
app.use(express.json());

// ============================================
// Utility: Run yt-dlp command
// ============================================
function runYtDlp(args, timeoutMs = 30000) {
  return new Promise((resolve, reject) => {
    const options = { 
      maxBuffer: 1024 * 1024 * 10,
      timeout: timeoutMs,
      env: { ...process.env, PYTHONIOENCODING: 'utf-8' }
    };
    execFile(YT_DLP_PATH, args, options, (error, stdout, stderr) => {
      if (error) {
        console.error('yt-dlp error:', stderr);
        reject(new Error(stderr || error.message));
        return;
      }
      resolve(stdout.trim());
    });
  });
}

// ============================================
// API: Search for songs
// GET /api/search?q=keyword&limit=20
// ============================================
app.get('/api/search', async (req, res) => {
  try {
    const query = req.query.q;
    const limit = parseInt(req.query.limit) || 20;

    if (!query) {
      return res.status(400).json({ error: 'Missing query parameter "q"' });
    }

    console.log(`🔍 Searching: "${query}" (limit: ${limit})`);

    let searchArg = `ytsearch${limit}:${query}`;
    
    // Check if the query is a YouTube URL
    const isUrl = query.includes('youtube.com/') || query.includes('youtu.be/');
    if (isUrl) {
      searchArg = query;
      console.log('🔗 URL detected, fetching as playlist/video...');
    }

    const args = [
      searchArg,
      '--flat-playlist',
      '--no-warnings',
      '--print', '%(id)s\t%(title)s\t%(channel)s\t%(duration)s\t%(thumbnail)s'
    ];

    const output = await runYtDlp(args);
    const lines = output.split('\n').filter(line => line.trim());

    const results = lines.map(line => {
      const [id, title, artist, duration, thumbnail] = line.split('\t');
      const cleanId = (id || '').trim();
      // Always use YouTube standard thumbnail — reliable 100% of the time
      const thumb = (thumbnail && thumbnail.startsWith('http'))
        ? thumbnail
        : `https://i.ytimg.com/vi/${cleanId}/mqdefault.jpg`;
      return {
        id: cleanId,
        title: title || 'ไม่ระบุชื่อเพลง',
        artist: artist || 'ไม่ระบุชื่อศิลปิน',
        duration: parseInt(duration) || 0,
        thumbnail: thumb
      };
    }).filter(item => item.id);

    console.log(`✅ Found ${results.length} results`);
    res.json({ results });

  } catch (error) {
    console.error('Search error:', error.message);
    res.status(500).json({ error: 'Search failed', message: error.message });
  }
});

// ============================================
// API: Get song info
// GET /api/info/:videoId
// ============================================
app.get('/api/info/:videoId', async (req, res) => {
  try {
    const { videoId } = req.params;
    console.log(`ℹ️ Getting info: ${videoId}`);

    const args = [
      `https://www.youtube.com/watch?v=${videoId}`,
      '--no-warnings',
      '--skip-download',
      '--print', '%(id)s\t%(title)s\t%(channel)s\t%(duration)s\t%(thumbnail)s\t%(view_count)s'
    ];

    const output = await runYtDlp(args);
    const [id, title, artist, duration, thumbnail, viewCount] = output.split('\t');
    const cleanId = (id || '').trim();
    const thumb = (thumbnail && thumbnail.startsWith('http'))
      ? thumbnail
      : `https://i.ytimg.com/vi/${cleanId}/mqdefault.jpg`;

    res.json({
      id: cleanId,
      title: title || 'Unknown',
      artist: artist || 'Unknown',
      duration: parseInt(duration) || 0,
      thumbnail: thumb,
      viewCount: parseInt(viewCount) || 0
    });

  } catch (error) {
    console.error('Info error:', error.message);
    res.status(500).json({ error: 'Failed to get info', message: error.message });
  }
});

// ============================================
// API: Get audio stream (proxied)
// GET /api/stream/:videoId
// 🎵 Optimized: ใช้ M4A format + caching
// ============================================
app.get('/api/stream/:videoId', async (req, res) => {
  try {
    const { videoId } = req.params;
    console.log(`🎵 Streaming: ${videoId}`);

    // Check cache first
    let audioUrl = getCachedUrl(videoId);
    
    if (!audioUrl) {
      // Prefer M4A (AAC) for best compatibility & smooth playback
      // M4A decodes much faster than Opus/WebM on mobile devices
      const args = [
        'https://www.youtube.com/watch?v=' + videoId,
        '-f', 'ba[ext=m4a][abr<=160]/ba[ext=m4a]/ba',
        '-g',
        '--no-warnings',
        '--no-playlist'
      ];

      audioUrl = await runYtDlp(args);
      audioUrl = audioUrl.split('\n')[0].trim();
      
      if (audioUrl) {
        setCachedUrl(videoId, audioUrl);
      }
    } else {
      console.log(`⚡ Cache hit for: ${videoId}`);
    }

    if (!audioUrl) {
      console.error(`❌ No audio URL found for ${videoId}`);
      return res.status(404).json({ error: 'No audio stream found' });
    }

    console.log(`🔗 Audio URL: ${audioUrl.substring(0, 80)}...`);

    // Helper to proxy with redirect support
    const proxyStream = (url, currentRes, currentReq, depth = 0) => {
      if (!url) {
        if (!currentRes.headersSent) {
          currentRes.status(500).json({ error: 'No stream URL' });
        }
        return;
      }

      if (depth > 5) {
        currentRes.status(500).json({ error: 'Too many redirects' });
        return;
      }

      const parsedUrl = new URL(url);
      const protocol = parsedUrl.protocol === 'https:' ? https : http;

      // Forward range headers for seeking support
      const headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Connection': 'keep-alive',
      };
      if (currentReq.headers.range) {
        headers['Range'] = currentReq.headers.range;
      }

      const proxyReq = protocol.get(url, { headers }, (proxyRes) => {
        // Handle Redirects
        if (proxyRes.statusCode >= 300 && proxyRes.statusCode < 400 && proxyRes.headers.location) {
          console.log(`↪️ Redirect [${depth}]: ${proxyRes.headers.location.substring(0, 80)}...`);
          proxyStream(proxyRes.headers.location, currentRes, currentReq, depth + 1);
          return;
        }

        // Forward response headers
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

        currentRes.writeHead(proxyRes.statusCode, responseHeaders);
        proxyRes.pipe(currentRes);
      });

      proxyReq.on('error', (error) => {
        console.error('Proxy error:', error.message);
        if (!currentRes.headersSent) {
          currentRes.status(500).json({ error: 'Stream failed' });
        }
      });

      // Cleanup on client disconnect
      currentReq.on('close', () => {
        proxyReq.destroy();
      });
    };

    proxyStream(audioUrl, res, req);

  } catch (error) {
    console.error('Stream error:', error.message);
    res.status(500).json({ error: 'Stream failed', message: error.message });
  }
});

// ============================================
// API: Get audio URL (direct CDN URL for Flutter)
// GET /api/audio-url/:videoId
// 🎵 Optimized: M4A preferred + caching
// ============================================
app.get('/api/audio-url/:videoId', async (req, res) => {
  try {
    const { videoId } = req.params;
    console.log(`🔗 Getting audio URL: ${videoId}`);

    // Check cache first
    let audioUrl = getCachedUrl(videoId);

    if (!audioUrl) {
      // Prefer M4A (AAC) — decodes faster, less CPU, no stuttering
      // Limit bitrate to 160kbps for smooth streaming over mobile networks
      const args = [
        'https://www.youtube.com/watch?v=' + videoId,
        '-f', 'ba[ext=m4a][abr<=160]/ba[ext=m4a]/ba',
        '-g',
        '--no-warnings',
        '--no-playlist'
      ];

      audioUrl = await runYtDlp(args);
      audioUrl = audioUrl.split('\n')[0].trim();

      if (audioUrl) {
        setCachedUrl(videoId, audioUrl);
        console.log(`✅ Resolved & cached: ${videoId}`);
      }
    } else {
      console.log(`⚡ Cache hit: ${videoId}`);
    }

    if (!audioUrl) {
      return res.status(404).json({ error: 'No audio URL found' });
    }

    res.json({ url: audioUrl });

  } catch (error) {
    console.error('Audio URL error:', error.message);
    res.status(500).json({ error: 'Failed to get audio URL', message: error.message });
  }
});

// ============================================
// API: Batch pre-resolve URLs (for queue pre-loading)
// POST /api/audio-urls
// Body: { videoIds: ["id1", "id2", ...] }
// ============================================
app.post('/api/audio-urls', async (req, res) => {
  try {
    const { videoIds } = req.body;
    if (!videoIds || !Array.isArray(videoIds)) {
      return res.status(400).json({ error: 'Missing videoIds array' });
    }

    console.log(`📦 Batch resolving ${videoIds.length} URLs...`);
    
    const results = {};
    
    // Resolve up to 5 at a time
    const batch = videoIds.slice(0, 5);
    
    await Promise.allSettled(batch.map(async (videoId) => {
      try {
        let url = getCachedUrl(videoId);
        if (!url) {
          const args = [
            'https://www.youtube.com/watch?v=' + videoId,
            '-f', 'ba[ext=m4a][abr<=160]/ba[ext=m4a]/ba',
            '-g',
            '--no-warnings',
            '--no-playlist'
          ];
          url = await runYtDlp(args);
          url = url.split('\n')[0].trim();
          if (url) setCachedUrl(videoId, url);
        }
        results[videoId] = url || null;
      } catch (e) {
        results[videoId] = null;
      }
    }));

    console.log(`✅ Batch resolved: ${Object.values(results).filter(v => v).length}/${batch.length}`);
    res.json({ urls: results });

  } catch (error) {
    console.error('Batch resolve error:', error.message);
    res.status(500).json({ error: 'Batch resolve failed', message: error.message });
  }
});

// ============================================
// API: Health check
// GET /api/health
// ============================================
app.get('/api/health', async (req, res) => {
  try {
    const version = await runYtDlp(['--version']);
    res.json({
      status: 'ok',
      ytdlp_version: version,
      cache_size: urlCache.size,
      server_time: new Date().toISOString()
    });
  } catch (error) {
    res.json({
      status: 'error',
      message: 'yt-dlp not found. Please install: pip install yt-dlp',
      server_time: new Date().toISOString()
    });
  }
});

// ============================================
// Start Server
// ============================================
app.listen(PORT, () => {
  console.log('');
  console.log('🎵 ═══════════════════════════════════════');
  console.log(`🎵  YT Music Server running on port ${PORT}`);
  console.log('🎵  Audio Engine: Professional Grade 🎧');
  console.log('🎵 ═══════════════════════════════════════');
  console.log('');
  console.log('📡 Endpoints:');
  console.log(`   GET  http://localhost:${PORT}/api/search?q=keyword`);
  console.log(`   GET  http://localhost:${PORT}/api/info/:videoId`);
  console.log(`   GET  http://localhost:${PORT}/api/stream/:videoId`);
  console.log(`   GET  http://localhost:${PORT}/api/audio-url/:videoId`);
  console.log(`   POST http://localhost:${PORT}/api/audio-urls`);
  console.log(`   GET  http://localhost:${PORT}/api/health`);
  console.log('');
});
