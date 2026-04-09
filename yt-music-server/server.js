const express = require('express');
const cors = require('cors');
const { execFile } = require('child_process');
const path = require('path');
const https = require('https');
const http = require('http');

const app = express();
const PORT = 3456;

// ============================================
// 🔧 Config
// ============================================
const CONFIG = {
  CACHE_TTL: 25 * 60 * 1000,       // 25 minutes
  CACHE_MAX: 200,
  CACHE_SWEEP: 20,                   // ลบ 20 entries เมื่อ cache เต็ม
  BATCH_MAX: 5,
  YTDLP_TIMEOUT: 30_000,
  MAX_REDIRECTS: 5,
  LOG: process.env.LOG === 'true',   // ปิด log โดย default, เปิดด้วย LOG=true
};

// yt-dlp executable path
const YT_DLP_PATH =
  process.platform === 'win32'
    ? path.join(process.env.APPDATA || '', 'Python', 'Python313', 'Scripts', 'yt-dlp.exe')
    : 'yt-dlp';

// ============================================
// Logger — ปิดทั้งหมดถ้า LOG=false
// ============================================
const log = {
  info: (...args) => CONFIG.LOG && console.log(...args),
  warn: (...args) => CONFIG.LOG && console.warn(...args),
  error: (...args) => CONFIG.LOG && console.error(...args),
};

// ============================================
// Validate videoId — ป้องกัน path traversal / injection
// ============================================
const VALID_VIDEO_ID = /^[a-zA-Z0-9_-]{6,16}$/;
function isValidVideoId(id) {
  return VALID_VIDEO_ID.test(id);
}

// ============================================
// URL Cache
// ============================================
const urlCache = new Map();

function getCachedUrl(videoId) {
  const cached = urlCache.get(videoId);
  if (cached && Date.now() - cached.timestamp < CONFIG.CACHE_TTL) {
    return cached.url;
  }
  urlCache.delete(videoId);
  return null;
}

function setCachedUrl(videoId, url) {
  urlCache.set(videoId, { url, timestamp: Date.now() });

  if (urlCache.size > CONFIG.CACHE_MAX) {
    // Sweep oldest N entries แทนการลบทีละ 1
    const keys = urlCache.keys();
    for (let i = 0; i < CONFIG.CACHE_SWEEP; i++) {
      const key = keys.next().value;
      if (key) urlCache.delete(key);
    }
  }
}

// ============================================
// Middleware
// ============================================
app.use(cors());
app.use(express.json());

// ============================================
// Utility: Run yt-dlp command
// ============================================
function runYtDlp(args, timeoutMs = CONFIG.YTDLP_TIMEOUT) {
  return new Promise((resolve, reject) => {
    const options = {
      maxBuffer: 1024 * 1024 * 10,
      timeout: timeoutMs,
      env: { ...process.env, PYTHONIOENCODING: 'utf-8' },
    };
    execFile(YT_DLP_PATH, args, options, (error, stdout, stderr) => {
      if (error) {
        log.error('yt-dlp error:', stderr);
        reject(new Error('yt-dlp failed'));   // ไม่รั่ว stderr ออก client
        return;
      }
      resolve(stdout.trim());
    });
  });
}

// ============================================
// Helper: Get audio URL (shared logic)
// ============================================
async function resolveAudioUrl(videoId) {
  let audioUrl = getCachedUrl(videoId);
  if (audioUrl) {
    log.info(`⚡ Cache hit: ${videoId}`);
    return audioUrl;
  }

  const args = [
    `https://www.youtube.com/watch?v=${videoId}`,
    '-f', 'ba[ext=m4a][abr<=160]/ba[ext=m4a]/ba',
    '-g',
    '--no-warnings',
    '--no-playlist',
  ];

  audioUrl = await runYtDlp(args);
  audioUrl = audioUrl.split('\n')[0].trim();

  if (audioUrl) {
    setCachedUrl(videoId, audioUrl);
    log.info(`✅ Resolved & cached: ${videoId}`);
  }

  return audioUrl || null;
}

// ============================================
// API: Search for songs
// GET /api/search?q=keyword&limit=20&offset=0
// ============================================
app.get('/api/search', async (req, res) => {
  try {
    const query = req.query.q;
    const limit = Math.min(parseInt(req.query.limit) || 20, 50);
    const offset = Math.max(parseInt(req.query.offset) || 0, 0);

    if (!query) {
      return res.status(400).json({ error: 'Missing query parameter "q"' });
    }

    log.info(`🔍 Searching: "${query}" (limit: ${limit}, offset: ${offset})`);

    const isUrl = query.includes('youtube.com/') || query.includes('youtu.be/');
    
    // หากเป็น URL ค้นหาตรงๆ ไม่ต้องใช้ Pagination
    // หากเป็นคำค้นหาทั่วไป ใช้ ytsearchN โดยที่ N คือจุดสิ้นสุดที่เราต้องการเข้าถึง
    const maxResults = offset + limit;
    const searchArg = isUrl ? query : `ytsearch${maxResults}:${query}`;

    const args = [
      searchArg,
      '--flat-playlist',
      '--no-warnings',
      '--playlist-start', (offset + 1).toString(),
      '--playlist-end', (offset + limit).toString(),
      '--print', '%(id)s\t%(title)s\t%(channel)s\t%(duration)s\t%(thumbnail)s',
    ];

    const output = await runYtDlp(args);
    const lines = output.split('\n').filter((line) => line.trim());

    const results = lines
      .map((line) => {
        const [id, title, artist, duration, thumbnail] = line.split('\t');
        const cleanId = (id || '').trim();
        if (!cleanId) return null;
        const thumb =
          thumbnail && thumbnail.startsWith('http')
            ? thumbnail
            : `https://i.ytimg.com/vi/${cleanId}/mqdefault.jpg`;
        return {
          id: cleanId,
          title: title || 'ไม่ระบุชื่อเพลง',
          artist: artist || 'ไม่ระบุชื่อศิลปิน',
          duration: parseInt(duration) || 0,
          thumbnail: thumb,
        };
      })
      .filter(Boolean);

    log.info(`✅ Found ${results.length} results (returning items ${offset + 1} to ${offset + results.length})`);
    res.json({ results });
  } catch (error) {
    log.error('Search error:', error.message);
    res.status(500).json({ error: 'Search failed' });
  }
});

// ============================================
// API: Get song info
// GET /api/info/:videoId
// ============================================
app.get('/api/info/:videoId', async (req, res) => {
  try {
    const { videoId } = req.params;

    if (!isValidVideoId(videoId)) {
      return res.status(400).json({ error: 'Invalid video ID' });
    }

    log.info(`ℹ️ Getting info: ${videoId}`);

    const args = [
      `https://www.youtube.com/watch?v=${videoId}`,
      '--no-warnings',
      '--skip-download',
      '--print', '%(id)s\t%(title)s\t%(channel)s\t%(duration)s\t%(thumbnail)s\t%(view_count)s',
    ];

    const output = await runYtDlp(args);
    const [id, title, artist, duration, thumbnail, viewCount] = output.split('\t');
    const cleanId = (id || '').trim();
    const thumb =
      thumbnail && thumbnail.startsWith('http')
        ? thumbnail
        : `https://i.ytimg.com/vi/${cleanId}/mqdefault.jpg`;

    res.json({
      id: cleanId,
      title: title || 'Unknown',
      artist: artist || 'Unknown',
      duration: parseInt(duration) || 0,
      thumbnail: thumb,
      viewCount: parseInt(viewCount) || 0,
    });
  } catch (error) {
    log.error('Info error:', error.message);
    res.status(500).json({ error: 'Failed to get info' });
  }
});

// ============================================
// API: Stream audio (proxied)
// GET /api/stream/:videoId
// ============================================
app.get('/api/stream/:videoId', async (req, res) => {
  try {
    const { videoId } = req.params;

    if (!isValidVideoId(videoId)) {
      return res.status(400).json({ error: 'Invalid video ID' });
    }

    log.info(`🎵 Streaming: ${videoId}`);

    const audioUrl = await resolveAudioUrl(videoId);
    if (!audioUrl) {
      return res.status(404).json({ error: 'No audio stream found' });
    }

    log.info(`🔗 Audio URL resolved for: ${videoId}`);

    const proxyStream = (url, depth = 0) => {
      if (depth > CONFIG.MAX_REDIRECTS) {
        if (!res.headersSent) res.status(500).json({ error: 'Too many redirects' });
        return;
      }

      const parsedUrl = new URL(url);
      const protocol = parsedUrl.protocol === 'https:' ? https : http;

      const headers = {
        'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Connection': 'keep-alive',
      };
      if (req.headers.range) {
        headers['Range'] = req.headers.range;
      }

      const proxyReq = protocol.get(url, { headers }, (proxyRes) => {
        if (proxyRes.statusCode >= 300 && proxyRes.statusCode < 400 && proxyRes.headers.location) {
          log.info(`↪️ Redirect [${depth}]`);
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
        log.error('Proxy error:', error.message);
        if (!res.headersSent) res.status(500).json({ error: 'Stream failed' });
      });

      req.on('close', () => proxyReq.destroy());
    };

    proxyStream(audioUrl);
  } catch (error) {
    log.error('Stream error:', error.message);
    res.status(500).json({ error: 'Stream failed' });
  }
});

// ============================================
// API: Get audio URL (direct CDN URL)
// GET /api/audio-url/:videoId
// ============================================
app.get('/api/audio-url/:videoId', async (req, res) => {
  try {
    const { videoId } = req.params;

    if (!isValidVideoId(videoId)) {
      return res.status(400).json({ error: 'Invalid video ID' });
    }

    log.info(`🔗 Getting audio URL: ${videoId}`);

    const audioUrl = await resolveAudioUrl(videoId);
    if (!audioUrl) {
      return res.status(404).json({ error: 'No audio URL found' });
    }

    res.json({ url: audioUrl });
  } catch (error) {
    log.error('Audio URL error:', error.message);
    res.status(500).json({ error: 'Failed to get audio URL' });
  }
});

// ============================================
// API: Batch pre-resolve URLs
// POST /api/audio-urls
// Body: { videoIds: ["id1", "id2", ...] }
// ============================================
app.post('/api/audio-urls', async (req, res) => {
  try {
    const { videoIds } = req.body;

    if (!Array.isArray(videoIds) || videoIds.length === 0) {
      return res.status(400).json({ error: 'Missing or empty videoIds array' });
    }

    const batch = videoIds
      .filter(isValidVideoId)
      .slice(0, CONFIG.BATCH_MAX);

    log.info(`📦 Batch resolving ${batch.length} URLs...`);

    const results = {};

    await Promise.allSettled(
      batch.map(async (videoId) => {
        try {
          results[videoId] = await resolveAudioUrl(videoId);
        } catch {
          results[videoId] = null;
        }
      })
    );

    log.info(`✅ Batch resolved: ${Object.values(results).filter(Boolean).length}/${batch.length}`);
    res.json({ urls: results });
  } catch (error) {
    log.error('Batch resolve error:', error.message);
    res.status(500).json({ error: 'Batch resolve failed' });
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
      server_time: new Date().toISOString(),
    });
  } catch {
    res.json({
      status: 'error',
      message: 'yt-dlp not found. Please install: pip install yt-dlp',
      server_time: new Date().toISOString(),
    });
  }
});

// ============================================
// Start Server
// ============================================
app.listen(PORT, () => {
  console.log(`🎵 YT Music Server running on port ${PORT} (LOG=${CONFIG.LOG})`);
});