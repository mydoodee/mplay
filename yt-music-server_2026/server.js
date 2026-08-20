const express = require("express");
const cors = require("cors");
const { execFile } = require("child_process");
const path = require("path");
const https = require("https");
const http = require("http");

const app = express();
app.use(cors());
app.use(express.json({ limit: "15mb" }));
app.use(express.static("public"));
const PORT = process.env.PORT || 3456;

// ============================================
// 🔧 Config
// ============================================
const CONFIG = {
  CACHE_TTL: 25 * 60 * 1000,           // 25 นาที — URL cache (เพลงปกติ)
  LIVE_CACHE_TTL: 3 * 60 * 1000,       // 3 นาที — Live URL หมดอายุเร็วกว่ามาก
  CACHE_MAX: 500,
  CACHE_SWEEP: 50,
  SEARCH_CACHE_TTL: 10 * 60 * 1000,   // 10 นาที — Search cache
  SEARCH_CACHE_MAX: 100,
  BATCH_MAX: 3,                         // 🔧 ลดจาก 15 → 3 เพื่อประหยัด CPU บน QNAP
  YTDLP_TIMEOUT: 30_000,
  MAX_REDIRECTS: 5,
  MAX_CONCURRENT_YTDLP: 2,             // 🔧 จำกัด yt-dlp สูงสุด 2 ตัวพร้อมกัน
  LOG: process.env.LOG === "true",
};

// yt-dlp executable path
const YT_DLP_PATH =
  process.platform === "win32"
    ? path.join(
        process.env.APPDATA || "",
        "Python",
        "Python313",
        "Scripts",
        "yt-dlp.exe",
      )
    : "yt-dlp";

// ============================================
// Logger — ปิดทั้งหมดถ้า LOG=false
// ============================================
const log = {
  info: (...args) => CONFIG.LOG && console.log(...args),
  warn: (...args) => CONFIG.LOG && console.warn(...args),
  error: (...args) => CONFIG.LOG && console.error(...args),
};

// ============================================
// 🔧 Semaphore — จำกัดจำนวน yt-dlp process ที่รันพร้อมกัน
// ป้องกัน CPU 100% บน QNAP เมื่อหลายเครื่องใช้งานพร้อมกัน
// ============================================
let _activeYtDlp = 0;
const _ytDlpQueue = [];

function acquireSemaphore() {
  return new Promise((resolve) => {
    if (_activeYtDlp < CONFIG.MAX_CONCURRENT_YTDLP) {
      _activeYtDlp++;
      resolve();
    } else {
      _ytDlpQueue.push(resolve);
    }
  });
}

function releaseSemaphore() {
  if (_ytDlpQueue.length > 0) {
    const next = _ytDlpQueue.shift();
    next(); // ส่งต่อให้ request ถัดไปที่รอคิวอยู่
  } else {
    _activeYtDlp--;
  }
}

// ============================================
// 🚀 URL Cache & Pending Resolutions (Coalescing)
// ============================================
const urlCache = new Map();
const pendingResolutions = new Map();

function getCachedUrl(videoId) {
  const cached = urlCache.get(videoId);
  if (!cached) return null;
  const ttl = cached.isLive ? CONFIG.LIVE_CACHE_TTL : CONFIG.CACHE_TTL;
  if (Date.now() - cached.timestamp < ttl) {
    return cached;
  }
  urlCache.delete(videoId);
  return null;
}

function setCachedUrl(videoId, url, isLive = false, isHls = false) {
  urlCache.set(videoId, { url, isLive, isHls, timestamp: Date.now() });
  if (urlCache.size > CONFIG.CACHE_MAX) {
    const keys = urlCache.keys();
    for (let i = 0; i < CONFIG.CACHE_SWEEP; i++) {
      const key = keys.next().value;
      if (key) urlCache.delete(key);
    }
  }
}

// ============================================
// 🔧 Search Cache & Pending Searches (Coalescing)
// ป้องกันการ spawn yt-dlp ซ้ำเมื่อค้นหาคำเดิม
// ============================================
const searchCache = new Map();
const pendingSearches = new Map();

function getCachedSearch(cacheKey) {
  const cached = searchCache.get(cacheKey);
  if (cached && Date.now() - cached.timestamp < CONFIG.SEARCH_CACHE_TTL) {
    return cached.results;
  }
  searchCache.delete(cacheKey);
  return null;
}

function setCachedSearch(cacheKey, results) {
  searchCache.set(cacheKey, { results, timestamp: Date.now() });
  if (searchCache.size > CONFIG.SEARCH_CACHE_MAX) {
    const keys = searchCache.keys();
    for (let i = 0; i < 20; i++) {
      const key = keys.next().value;
      if (key) searchCache.delete(key);
    }
  }
}

// ============================================
// Middleware
// ============================================
app.use(cors());
app.use(express.json());

// ============================================
// Utility: Run yt-dlp command (with Semaphore)
// ============================================
function runYtDlp(args, timeoutMs = CONFIG.YTDLP_TIMEOUT) {
  return new Promise((resolve, reject) => {
    const options = {
      maxBuffer: 1024 * 1024 * 10,
      timeout: timeoutMs,
      env: { ...process.env, PYTHONIOENCODING: "utf-8" },
    };
    execFile(YT_DLP_PATH, args, options, (error, stdout, stderr) => {
      if (error) {
        log.error("yt-dlp error:", stderr);
        reject(new Error("yt-dlp failed"));
        return;
      }
      resolve(stdout.trim());
    });
  });
}

// runYtDlp แบบมี Semaphore ป้องกัน CPU spike
async function runYtDlpLimited(args, timeoutMs = CONFIG.YTDLP_TIMEOUT) {
  await acquireSemaphore();
  try {
    return await runYtDlp(args, timeoutMs);
  } finally {
    releaseSemaphore();
  }
}

// ============================================
// Helper: Get audio URL (shared logic)
// Returns: { url, isLive, isHls } or null
// ============================================
async function resolveAudioUrl(videoId) {
  // 1. Check Cache
  const cachedEntry = getCachedUrl(videoId);
  if (cachedEntry) return cachedEntry;

  // 2. Check if already resolving (Request Coalescing)
  if (pendingResolutions.has(videoId)) {
    log.info(`⏳ Coalescing URL request for: ${videoId}`);
    return pendingResolutions.get(videoId);
  }

  // 3. Resolve using yt-dlp — ดึง is_live ด้วย
  const resolutionPromise = (async () => {
    try {
      // ดึง JSON metadata เพื่อตรวจ is_live + hls_manifest_url
      const infoArgs = [
        `https://www.youtube.com/watch?v=${videoId}`,
        "--no-warnings",
        "--no-playlist",
        "--no-check-certificates",
        "--no-cache-dir",
        "--extractor-args",
        "youtube:player_client=android,web,mweb",
        "--print",
        "%(is_live)s\t%(live_status)s\t%(url)s\t%(hls_manifest_url)s",
        "-f",
        "bestaudio/best",
      ];

      let output = await runYtDlpLimited(infoArgs);
      output = output.split("\n")[0].trim();
      const parts = output.split("\t");

      const rawIsLive = parts[0] || "";
      const liveStatus = parts[1] || "";
      const directUrl = (parts[2] || "").trim();
      const hlsUrl = (parts[3] || "").trim();

      // ตรวจว่าเป็น live หรือไม่
      const isLive = rawIsLive === "True" || liveStatus === "is_live" || liveStatus === "is_upcoming";
      const isHls = isLive && hlsUrl && hlsUrl.startsWith("http");

      const finalUrl = isHls ? hlsUrl : directUrl;

      if (finalUrl) {
        setCachedUrl(videoId, finalUrl, isLive, isHls);
        log.info(`✅ Resolved: ${videoId} isLive=${isLive} isHls=${isHls}`);
        return { url: finalUrl, isLive, isHls };
      }
      return null;
    } catch (err) {
      log.error(`❌ Resolve failed for ${videoId}:`, err.message);
      return null;
    } finally {
      pendingResolutions.delete(videoId);
    }
  })();

  pendingResolutions.set(videoId, resolutionPromise);
  return resolutionPromise;
}

// ============================================
// API: Search for songs
// GET /api/search?q=keyword&limit=20&offset=0
// ============================================
app.get("/api/search", async (req, res) => {
  try {
    const query = req.query.q;
    const limit = Math.min(parseInt(req.query.limit) || 20, 50);
    const offset = Math.max(parseInt(req.query.offset) || 0, 0);

    if (!query) {
      return res.status(400).json({ error: 'Missing query parameter "q"' });
    }

    // 🔧 Cache Key รวม query + offset + limit
    const cacheKey = `${query.toLowerCase().trim()}__${offset}__${limit}`;

    // 1. ตรวจ Search Cache ก่อน — คืนผลทันทีโดยไม่ต้อง spawn yt-dlp
    const cached = getCachedSearch(cacheKey);
    if (cached) {
      log.info(`⚡ Search cache hit: "${query}"`);
      return res.json({ results: cached });
    }

    // 2. Coalescing — ถ้ากำลังค้นหาคำเดิมอยู่ ให้รอผลจากอันเดิม
    if (pendingSearches.has(cacheKey)) {
      log.info(`⏳ Coalescing search for: "${query}"`);
      const results = await pendingSearches.get(cacheKey);
      return res.json({ results: results || [] });
    }

    log.info(`🔍 Searching: "${query}" (limit: ${limit}, offset: ${offset})`);

    // 3. รัน yt-dlp (จำกัดด้วย Semaphore)
    const isUrl = query.includes("youtube.com/") || query.includes("youtu.be/");
    const maxResults = offset + limit;
    const searchArg = isUrl ? query : `ytsearch${maxResults}:${query}`;

    const args = [
      searchArg,
      "--flat-playlist",
      "--no-warnings",
      "--playlist-start",
      (offset + 1).toString(),
      "--playlist-end",
      (offset + limit).toString(),
      "--print",
      "%(id)s\t%(title)s\t%(channel)s\t%(duration)s\t%(thumbnail)s",
    ];

    const searchPromise = (async () => {
      try {
        const output = await runYtDlpLimited(args);
        const lines = output.split("\n").filter((line) => line.trim());

        const results = lines
          .map((line) => {
            const [id, title, artist, duration, thumbnail] = line.split("\t");
            const cleanId = (id || "").trim();
            if (!cleanId) return null;
            const thumb =
              thumbnail && thumbnail.startsWith("http")
                ? thumbnail
                : `https://i.ytimg.com/vi/${cleanId}/mqdefault.jpg`;
            return {
              id: cleanId,
              title: title || "ไม่ระบุชื่อเพลง",
              artist: artist || "ไม่ระบุชื่อศิลปิน",
              duration: parseInt(duration) || 0,
              thumbnail: thumb,
              isLive: duration === "0" || duration === "None", // yt-dlp คืน 0/None สำหรับ live
            };
          })
          .filter(Boolean);

        // บันทึก Cache
        setCachedSearch(cacheKey, results);
        log.info(`✅ Search done & cached: "${query}" → ${results.length} results`);
        return results;
      } catch (err) {
        log.error("Search yt-dlp error:", err.message);
        return null;
      } finally {
        pendingSearches.delete(cacheKey);
      }
    })();

    pendingSearches.set(cacheKey, searchPromise);

    const results = await searchPromise;
    if (results === null) {
      return res.status(500).json({ error: "Search failed" });
    }
    res.json({ results });
  } catch (error) {
    log.error("Search error:", error.message);
    res.status(500).json({ error: "Search failed" });
  }
});

// ============================================
// API: Get song info
// GET /api/info/:videoId
// ============================================
app.get("/api/info/:videoId", async (req, res) => {
  try {
    const { videoId } = req.params;

    if (!isValidVideoId(videoId)) {
      return res.status(400).json({ error: "Invalid video ID" });
    }

    log.info(`ℹ️ Getting info: ${videoId}`);

    const args = [
      `https://www.youtube.com/watch?v=${videoId}`,
      "--no-warnings",
      "--skip-download",
      "--print",
      "%(id)s\t%(title)s\t%(channel)s\t%(duration)s\t%(thumbnail)s\t%(view_count)s",
    ];

    const output = await runYtDlpLimited(args);
    const [id, title, artist, duration, thumbnail, viewCount] =
      output.split("\t");
    const cleanId = (id || "").trim();
    const thumb =
      thumbnail && thumbnail.startsWith("http")
        ? thumbnail
        : `https://i.ytimg.com/vi/${cleanId}/mqdefault.jpg`;

    res.json({
      id: cleanId,
      title: title || "Unknown",
      artist: artist || "Unknown",
      duration: parseInt(duration) || 0,
      thumbnail: thumb,
      viewCount: parseInt(viewCount) || 0,
      isLive: duration === "0" || duration === "None",
    });
  } catch (error) {
    log.error("Info error:", error.message);
    res.status(500).json({ error: "Failed to get info" });
  }
});

// ============================================
// API: Stream audio (proxied)
// GET /api/stream/:videoId
// ============================================
app.get("/api/stream/:videoId", async (req, res) => {
  try {
    const { videoId } = req.params;

    if (!isValidVideoId(videoId)) {
      return res.status(400).json({ error: "Invalid video ID" });
    }

    log.info(`🎵 Streaming: ${videoId}`);

    const resolved = await resolveAudioUrl(videoId);
    if (!resolved) {
      return res.status(404).json({ error: "No audio stream found" });
    }

    const { url: audioUrl, isLive, isHls } = resolved;
    log.info(`🔗 Audio URL resolved for: ${videoId} (isLive=${isLive})`);

    // 🔴 Live/HLS: proxy manifest พร้อม Content-Type ที่ถูกต้อง
    // ไม่ใช้ redirect เพราะ ExoPlayer รู้จัก HLS จาก Content-Type หรือ .m3u8 extension
    // YouTube HLS URL ไม่ลงท้าย .m3u8 ดังนั้นต้อง proxy ต้องกำหนด Content-Type เอง
    if (isLive || isHls) {
      log.info(`📡 Live stream — proxying HLS manifest: ${videoId}`);
      const parsedHlsUrl = new URL(audioUrl);
      const hlsProtocol = parsedHlsUrl.protocol === "https:" ? https : http;
      const hlsReq = hlsProtocol.get(
        audioUrl,
        {
          headers: {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
            "Accept-Encoding": "identity",  // ป้องกัน GZIP double-decode
          },
        },
        (hlsRes) => {
          if (!res.headersSent) {
            // ตั้ง Content-Type เพื่อให้ ExoPlayer รู้จักว่าเป็น HLS
            res.setHeader("Content-Type", "application/vnd.apple.mpegurl");
            res.setHeader("Access-Control-Allow-Origin", "*");
            res.setHeader("Cache-Control", "no-cache");
            res.status(200);
            hlsRes.pipe(res);
          }
        }
      );
      hlsReq.on("error", (err) => {
        log.error("HLS proxy error:", err.message);
        if (!res.headersSent) res.status(500).json({ error: "HLS proxy failed" });
      });
      req.on("close", () => hlsReq.destroy());
      return;
    }

    const isClientRange = Boolean(req.headers.range);
    const proxyStream = (url, depth = 0) => {
      if (depth > CONFIG.MAX_REDIRECTS) {
        if (!res.headersSent)
          res.status(500).json({ error: "Too many redirects" });
        return;
      }

      const parsedUrl = new URL(url);
      const protocol = parsedUrl.protocol === "https:" ? https : http;

      const headers = {
        Connection: "keep-alive",
        "Accept-Encoding": "identity",
      };
      headers["Range"] = req.headers.range || "bytes=0-";
      if (req.headers["user-agent"]) {
        headers["User-Agent"] = req.headers["user-agent"];
      }

      const proxyReq = protocol.get(url, { headers }, (proxyRes) => {
        if (
          proxyRes.statusCode >= 300 &&
          proxyRes.statusCode < 400 &&
          proxyRes.headers.location
        ) {
          log.info(`↪️ Redirect [${depth}]`);
          proxyStream(proxyRes.headers.location, depth + 1);
          return;
        }

        const responseHeaders = {
          "Content-Type": proxyRes.headers["content-type"] || "audio/mp4",
          "Accept-Ranges": "bytes",
          "Cache-Control": "no-cache",
          "Access-Control-Allow-Origin": "*",
          Connection: "keep-alive",
        };

        if (proxyRes.headers["content-length"]) {
          responseHeaders["Content-Length"] =
            proxyRes.headers["content-length"];
        }

        let statusCode = proxyRes.statusCode;
        if (isClientRange && proxyRes.headers["content-range"]) {
          responseHeaders["Content-Range"] = proxyRes.headers["content-range"];
        } else if (!isClientRange && statusCode === 206) {
          statusCode = 200;
        }

        res.writeHead(statusCode, responseHeaders);
        proxyRes.pipe(res);
      });

      proxyReq.on("error", (error) => {
        log.error("Proxy error:", error.message);
        if (!res.headersSent) res.status(500).json({ error: "Stream failed" });
      });

      req.on("close", () => proxyReq.destroy());
    };

    proxyStream(audioUrl);
  } catch (error) {
    log.error("Stream error:", error.message);
    res.status(500).json({ error: "Stream failed" });
  }
});

// ============================================
// API: Get audio URL (direct CDN or Stream Proxy URL)
// GET /api/audio-url/:videoId
// ============================================
app.get("/api/audio-url/:videoId", async (req, res) => {
  try {
    const { videoId } = req.params;

    if (!isValidVideoId(videoId)) {
      return res.status(400).json({ error: "Invalid video ID" });
    }

    log.info(`🔗 Getting audio URL: ${videoId}`);

    const resolved = await resolveAudioUrl(videoId);
    if (!resolved) {
      return res.status(404).json({ error: "No audio stream found" });
    }

    const host = req.get("host") || "music.growkub.com";
    const protocol = req.headers["x-forwarded-proto"] || req.protocol || "https";
    const streamProxyUrl = `${protocol}://${host}/api/stream/${videoId}`;

    // For regular streams, return stream proxy URL so phone avoids YouTube IP lock
    const playbackUrl = (resolved.isLive || resolved.isHls) ? resolved.url : streamProxyUrl;

    res.json({
      url: playbackUrl,
      isLive: resolved.isLive || false,
      isHls: resolved.isHls || false,
    });
  } catch (error) {
    log.error("Audio URL error:", error.message);
    res.status(500).json({ error: "Failed to get audio URL" });
  }
});

// ============================================
// API: Batch pre-resolve URLs
// POST /api/audio-urls
// Body: { videoIds: ["id1", "id2", ...] }
// ============================================
app.post("/api/audio-urls", async (req, res) => {
  try {
    const { videoIds } = req.body;

    if (!Array.isArray(videoIds) || videoIds.length === 0) {
      return res.status(400).json({ error: "Missing or empty videoIds array" });
    }

    // 🔧 จำกัด BATCH_MAX = 3 เพื่อป้องกัน CPU spike บน QNAP
    const batch = videoIds.filter(isValidVideoId).slice(0, CONFIG.BATCH_MAX);

    log.info(`📦 Batch resolving ${batch.length} URLs (max ${CONFIG.BATCH_MAX})...`);

    const host = req.get("host") || "music.growkub.com";
    const protocol = req.headers["x-forwarded-proto"] || req.protocol || "https";

    const results = {};

    // 🔧 รันแบบ sequential แทน parallel เพื่อไม่ให้ Semaphore คิวยาว
    for (const videoId of batch) {
      try {
        const resolved = await resolveAudioUrl(videoId);
        if (resolved) {
          const streamProxyUrl = `${protocol}://${host}/api/stream/${videoId}`;
          results[videoId] = (resolved.isLive || resolved.isHls) ? resolved.url : streamProxyUrl;
        } else {
          results[videoId] = null;
        }
      } catch {
        results[videoId] = null;
      }
    }

    log.info(
      `✅ Batch resolved: ${Object.values(results).filter(Boolean).length}/${batch.length}`,
    );
    res.json({ urls: results });
  } catch (error) {
    log.error("Batch resolve error:", error.message);
    res.status(500).json({ error: "Batch resolve failed" });
  }
});

// ============================================
// API: Health check
// GET /health and /api/health
// ============================================
app.get("/health", (req, res) => res.json({ status: "ok" }));
app.get("/api/health", async (req, res) => {
  try {
    const version = await runYtDlp(["--version"]);
    res.json({
      status: "ok",
      ytdlp_version: version,
      url_cache_size: urlCache.size,
      search_cache_size: searchCache.size,
      active_ytdlp: _activeYtDlp,
      queued_ytdlp: _ytDlpQueue.length,
      server_time: new Date().toISOString(),
    });
  } catch {
    res.json({
      status: "error",
      message: "yt-dlp not found. Please install: pip install yt-dlp",
      server_time: new Date().toISOString(),
    });
  }
});

// ============================================
// API: Heartbeat
// POST /api/heartbeat
// ============================================
app.post("/api/heartbeat", (req, res) => {
  const { deviceId, deviceName, platform } = req.body;
  log.info(`❤️ Heartbeat from ${deviceName} (${platform}) — ${deviceId}`);
  res.json({ status: "ok" });
});

// ============================================
// API: Speech-to-Text (Groq Whisper AI Fallback)
// POST /api/speech-to-text
// ============================================
app.post("/api/speech-to-text", async (req, res) => {
  try {
    const { audio, locale = "th-TH" } = req.body;

    if (!audio) {
      return res.status(400).json({ error: "Missing audio data" });
    }

    const groqKey = process.env.GROQ_API_KEY || "";
    if (!groqKey) {
      return res.status(503).json({ error: "GROQ_API_KEY not configured" });
    }

    const audioBuffer = Buffer.from(audio, "base64");
    const lang = locale.toLowerCase().startsWith("th") ? "th" : "en";

    // สร้าง Multipart Form-Data แบบ Native (ไม่ต้องใช้ npm library เพิ่มเติม)
    const boundary = "----WebKitFormBoundary" + Math.random().toString(36).substring(2);
    const parts = [];

    const fields = {
      model: "whisper-large-v3-turbo",
      language: lang,
      temperature: "0.0",
      response_format: "json",
    };

    for (const [key, value] of Object.entries(fields)) {
      parts.push(
        Buffer.from(
          `--${boundary}\r\nContent-Disposition: form-data; name="${key}"\r\n\r\n${value}\r\n`
        )
      );
    }

    parts.push(
      Buffer.from(
        `--${boundary}\r\nContent-Disposition: form-data; name="file"; filename="speech.m4a"\r\nContent-Type: audio/m4a\r\n\r\n`
      )
    );
    parts.push(audioBuffer);
    parts.push(Buffer.from(`\r\n--${boundary}--\r\n`));

    const postBody = Buffer.concat(parts);

    const options = {
      hostname: "api.groq.com",
      path: "/openai/v1/audio/transcriptions",
      method: "POST",
      headers: {
        Authorization: `Bearer ${groqKey}`,
        "Content-Type": `multipart/form-data; boundary=${boundary}`,
        "Content-Length": postBody.length,
      },
    };

    const reqGroq = https.request(options, (resGroq) => {
      let body = "";
      resGroq.on("data", (chunk) => (body += chunk));
      resGroq.on("end", () => {
        try {
          const json = JSON.parse(body);
          if (json.text) {
            log.info(`🤖 Groq Whisper recognized: "${json.text}"`);
            return res.json({ text: json.text, success: true });
          } else {
            log.warn("⚠️ Groq Whisper output empty:", body);
            return res.json({ text: null, success: true });
          }
        } catch (e) {
          log.error("Groq response parse error:", e.message, body);
          return res.status(500).json({ error: "Failed to parse Groq response" });
        }
      });
    });

    reqGroq.on("error", (e) => {
      log.error("Groq API request error:", e.message);
      return res.status(500).json({ error: "Groq Whisper API request failed" });
    });

    reqGroq.write(postBody);
    reqGroq.end();
  } catch (error) {
    log.error("Speech-to-text error:", error.message);
    res.status(500).json({ error: "Speech recognition failed" });
  }
});

// ============================================
// Validate videoId — ป้องกัน path traversal / injection
// ============================================
const VALID_VIDEO_ID = /^[a-zA-Z0-9_-]{6,16}$/;
function isValidVideoId(id) {
  return VALID_VIDEO_ID.test(id);
}

// ============================================
// Start Server
// ============================================
app.listen(PORT, () => {
  console.log(`🚀 M-PLAY Server running on port ${PORT} (LOG=${CONFIG.LOG})`);
  console.log(`⚙️  MAX_CONCURRENT_YTDLP=${CONFIG.MAX_CONCURRENT_YTDLP}, BATCH_MAX=${CONFIG.BATCH_MAX}`);
});
