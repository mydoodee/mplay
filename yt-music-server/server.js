const express = require("express");
const cors = require("cors");
const { execFile, spawn } = require("child_process");
const path = require("path");
const fs = require("fs");
const https = require("https");
const http = require("http");
const readline = require("readline");

// 🚀 v82: Keep-alive agents — reuse TLS connections to googlevideo (saves ~100-300ms per request)
const httpsAgent = new https.Agent({ keepAlive: true, maxSockets: 64, keepAliveMsecs: 15_000 });
const httpAgent = new http.Agent({ keepAlive: true, maxSockets: 64, keepAliveMsecs: 15_000 });

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
  MAX_CONCURRENT_YTDLP: 2,             // 🔧 จำกัด yt-dlp สูงสุด 2 ตัวพร้อมกัน (เฉพาะ CLI fallback)
  LOG: process.env.LOG === "true",

  // 🚀 v82: Persistent worker pool + prewarm + persistent cache
  POOL_SIZE: parseInt(process.env.POOL_SIZE) || 2,           // จำนวน Python worker ที่เปิดค้างไว้
  WORKER_TIMEOUT: 25_000,                                    // timeout ต่อ 1 งานใน worker
  WORKER_MAX_JOBS: 300,                                      // recycle worker หลังทำครบ N งาน (กัน memory โต)
  PREWARM_ON_SEARCH: parseInt(process.env.PREWARM_ON_SEARCH ?? "4"), // resolve เพลงบนสุดของผลค้นหาล่วงหน้า
  PREWARM_MAX_QUEUE: 30,                                     // คิว prewarm สูงสุด (กัน CPU ล้น)
  MAX_CACHE_TTL: 5 * 60 * 60 * 1000,                         // สูงสุด 5 ชม. (YouTube URL อยู่ได้ ~6 ชม.)
  EXPIRE_SAFETY: 20 * 60 * 1000,                             // หมดอายุก่อน YouTube 20 นาที
  CACHE_FILE: process.env.CACHE_FILE || path.join(__dirname, ".cache", "url-cache.json"),
  CACHE_SAVE_INTERVAL: 60_000,
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
  if (Date.now() < cached.expiresAt) {
    return cached;
  }
  urlCache.delete(videoId);
  return null;
}

// 🚀 v82: TTL ตามเวลาหมดอายุจริงของ YouTube (?expire=...) แทน 25 นาทีตายตัว
function computeExpiresAt(url, isLive) {
  const now = Date.now();
  if (isLive) return now + CONFIG.LIVE_CACHE_TTL;
  let ttl = CONFIG.CACHE_TTL;
  try {
    const u = new URL(url);
    let expire = parseInt(u.searchParams.get("expire"));
    if (!expire) {
      const m = u.pathname.match(/\/expire\/(\d+)/);
      if (m) expire = parseInt(m[1]);
    }
    if (expire) {
      ttl = Math.min(expire * 1000 - now - CONFIG.EXPIRE_SAFETY, CONFIG.MAX_CACHE_TTL);
    }
  } catch {}
  return now + Math.max(ttl, 60_000);
}

function setCachedUrl(videoId, url, isLive = false, isHls = false) {
  urlCache.delete(videoId); // re-insert → ย้ายไปท้าย Map (LRU-ish)
  urlCache.set(videoId, {
    url,
    isLive,
    isHls,
    timestamp: Date.now(),
    expiresAt: computeExpiresAt(url, isLive),
  });
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
// 🚀 v82: Persistent yt-dlp Worker Pool (resolver.py)
// - yt-dlp ถูก import ค้างไว้ใน memory → ไม่ต้องเสียเวลาเปิด Python ใหม่ทุกครั้ง
// - คิว 2 ระดับ: "high" = ผู้ใช้กดเล่น/ค้นหา, "low" = prewarm เบื้องหลัง
// - ถ้า worker ใช้ไม่ได้ → fallback ไปใช้ yt-dlp CLI แบบเดิม
// ============================================
const PYTHON_BIN = process.env.PYTHON_BIN || (process.platform === "win32" ? "python" : "python3");
const RESOLVER_SCRIPT = path.join(__dirname, "resolver.py");

class WorkerPool {
  constructor(size) {
    this.size = size;
    this.workers = [];
    this.high = [];
    this.low = [];
    this.seq = 1;
    this.disabled = !fs.existsSync(RESOLVER_SCRIPT);
    this.stats = { done: 0, failed: 0, restarts: 0 };
    if (this.disabled) {
      console.warn("⚠️ resolver.py not found — using yt-dlp CLI only");
      return;
    }
    for (let i = 0; i < size; i++) this._spawn(i);
  }

  _spawn(slot) {
    const proc = spawn(PYTHON_BIN, ["-u", RESOLVER_SCRIPT], {
      env: { ...process.env, PYTHONIOENCODING: "utf-8" },
      stdio: ["pipe", "pipe", "ignore"],
    });
    const w = { slot, proc, ready: false, busy: null, jobs: 0, dead: false };
    this.workers[slot] = w;

    readline.createInterface({ input: proc.stdout }).on("line", (line) => {
      let msg;
      try { msg = JSON.parse(line); } catch { return; }
      if (msg.ready) {
        w.ready = true;
        log.info(`🐍 Worker #${slot} ready (yt-dlp ${msg.version})`);
        this._dispatch();
        return;
      }
      const job = w.busy;
      if (!job || msg.id !== job.id) return;
      clearTimeout(job.timer);
      w.busy = null;
      w.jobs++;
      if (msg.ok) { this.stats.done++; job.resolve(msg); }
      else { this.stats.failed++; job.reject(new Error(msg.error || "worker error")); }
      if (w.jobs >= CONFIG.WORKER_MAX_JOBS) this._recycle(w);
      else this._dispatch();
    });

    const onExit = () => {
      if (w.dead) return;
      w.dead = true;
      if (w.busy) {
        clearTimeout(w.busy.timer);
        w.busy.reject(new Error("worker exited"));
        w.busy = null;
      }
      this.stats.restarts++;
      // ถ้าตายติดกันเร็วเกินไป (เช่น python ไม่มี) ให้รอนานขึ้น
      setTimeout(() => { if (this.workers[slot] === w) this._spawn(slot); }, 2000);
    };
    proc.on("exit", onExit);
    proc.on("error", (err) => {
      log.error(`🐍 Worker #${slot} spawn error:`, err.message);
      onExit();
    });
  }

  _recycle(w) {
    w.ready = false;
    try { w.proc.kill(); } catch {}
  }

  get readyCount() {
    return this.workers.filter((w) => w && w.ready && !w.dead).length;
  }

  available() {
    return !this.disabled && this.readyCount > 0;
  }

  run(payload, priority = "high") {
    return new Promise((resolve, reject) => {
      const job = { id: this.seq++, payload, resolve, reject, timer: null };
      if (priority === "low") {
        if (this.low.length >= CONFIG.PREWARM_MAX_QUEUE) {
          return reject(new Error("prewarm queue full"));
        }
        this.low.push(job);
      } else {
        this.high.push(job);
      }
      this._dispatch();
    });
  }

  // ย้ายงาน low → high (เมื่อผู้ใช้กดเล่นเพลงที่กำลังรอ prewarm อยู่)
  promote(predicate) {
    const idx = this.low.findIndex((j) => predicate(j.payload));
    if (idx !== -1) {
      const [job] = this.low.splice(idx, 1);
      this.high.unshift(job);
      this._dispatch();
    }
  }

  _dispatch() {
    for (const w of this.workers) {
      if (!w || !w.ready || w.dead || w.busy) continue;
      const job = this.high.shift() || this.low.shift();
      if (!job) return;
      w.busy = job;
      job.timer = setTimeout(() => {
        if (w.busy === job) {
          log.warn(`⏱ Worker #${w.slot} job timeout — restarting worker`);
          w.busy = null;
          this.stats.failed++;
          job.reject(new Error("worker timeout"));
          this._recycle(w);
        }
      }, CONFIG.WORKER_TIMEOUT);
      try {
        w.proc.stdin.write(JSON.stringify({ id: job.id, ...job.payload }) + "\n");
      } catch (err) {
        clearTimeout(job.timer);
        w.busy = null;
        job.reject(err);
        this._recycle(w);
      }
    }
  }

  shutdown() {
    for (const w of this.workers) {
      if (!w) continue;
      w.dead = true;
      try { w.proc.kill(); } catch {}
    }
  }
}

const pool = new WorkerPool(CONFIG.POOL_SIZE);

// ============================================
// 🚀 v82: Persistent URL cache (รอด restart container)
// ============================================
function loadUrlCache() {
  try {
    const raw = fs.readFileSync(CONFIG.CACHE_FILE, "utf-8");
    const data = JSON.parse(raw);
    const now = Date.now();
    let n = 0;
    for (const [id, entry] of Object.entries(data)) {
      if (entry && entry.url && entry.expiresAt > now && !entry.isLive) {
        urlCache.set(id, entry);
        n++;
      }
    }
    console.log(`💾 Loaded ${n} cached URLs from disk`);
  } catch {}
}

function saveUrlCache() {
  try {
    const now = Date.now();
    const out = {};
    for (const [id, entry] of urlCache) {
      if (!entry.isLive && entry.expiresAt > now) out[id] = entry;
    }
    fs.mkdirSync(path.dirname(CONFIG.CACHE_FILE), { recursive: true });
    const tmp = CONFIG.CACHE_FILE + ".tmp";
    fs.writeFileSync(tmp, JSON.stringify(out));
    fs.renameSync(tmp, CONFIG.CACHE_FILE);
  } catch (err) {
    log.warn("Cache save failed:", err.message);
  }
}

loadUrlCache();
setInterval(saveUrlCache, CONFIG.CACHE_SAVE_INTERVAL).unref();

// ============================================
// 🚀 v82: Prewarm — resolve เพลงล่วงหน้าเบื้องหลัง (priority ต่ำ)
// ทำให้ผู้ใช้กดเพลงแล้วเล่นทันที (cache hit ~50ms)
// ============================================
function prewarm(videoIds) {
  let queued = 0;
  for (const id of videoIds) {
    if (!isValidVideoId(id)) continue;
    if (getCachedUrl(id) || pendingResolutions.has(id)) continue;
    resolveAudioUrl(id, "low").catch(() => null);
    queued++;
  }
  return queued;
}

// ============================================
// Helper: Get audio URL (shared logic)
// Returns: { url, isLive, isHls } or null
// ============================================
async function resolveAudioUrl(videoId, priority = "high") {
  // 1. Check Cache
  const cachedEntry = getCachedUrl(videoId);
  if (cachedEntry) return cachedEntry;

  // 2. Check if already resolving (Request Coalescing)
  if (pendingResolutions.has(videoId)) {
    log.info(`⏳ Coalescing URL request for: ${videoId}`);
    // ผู้ใช้กดเพลงที่กำลังรอ prewarm อยู่ → ดันขึ้นหัวคิว
    if (priority !== "high") return pendingResolutions.get(videoId);
    pool.promote((p) => p.op === "resolve" && p.videoId === videoId);
    const shared = await pendingResolutions.get(videoId);
    if (shared) return shared;
    // prewarm (priority ต่ำ) ล้มเหลว → ลองใหม่แบบ high (มี CLI fallback)
    if (pendingResolutions.has(videoId)) return pendingResolutions.get(videoId);
    const cachedNow = getCachedUrl(videoId);
    if (cachedNow) return cachedNow;
  }

  // 3. Resolve — worker pool ก่อน (เร็ว), ถ้าล้มเหลว fallback เป็น yt-dlp CLI แบบเดิม
  const resolutionPromise = (async () => {
    if (pool.available()) {
      try {
        const t0 = Date.now();
        const r = await pool.run({ op: "resolve", videoId }, priority);
        if (r && r.url) {
          setCachedUrl(videoId, r.url, !!r.isLive, !!r.isHls);
          log.info(`⚡ Worker resolved ${videoId} in ${Date.now() - t0}ms (${priority}) isLive=${r.isLive}`);
          return getCachedUrl(videoId);
        }
      } catch (err) {
        log.warn(`⚠️ Worker resolve failed for ${videoId}: ${err.message} → CLI fallback`);
        if (priority === "low") {
          // prewarm ล้มเหลว → ไม่ต้อง fallback (ประหยัด CPU) ให้ผู้ใช้กดแล้วค่อยลองใหม่
          return null;
        }
      }
    }
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
    }
  })();

  const tracked = resolutionPromise.finally(() => {
    if (pendingResolutions.get(videoId) === tracked) pendingResolutions.delete(videoId);
  });
  pendingResolutions.set(videoId, tracked);
  return tracked;
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
      res.json({ results: cached });
      if (offset === 0 && CONFIG.PREWARM_ON_SEARCH > 0) {
        prewarm(cached.filter((r) => !r.isLive).slice(0, CONFIG.PREWARM_ON_SEARCH).map((r) => r.id));
      }
      return;
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
      // 🚀 v82: ค้นหาผ่าน worker ก่อน (ไม่ต้องเปิด Python ใหม่)
      if (pool.available()) {
        try {
          const r = await pool.run({ op: "search", query, offset, limit }, "high");
          if (r && Array.isArray(r.results)) {
            setCachedSearch(cacheKey, r.results);
            log.info(`⚡ Worker search: "${query}" → ${r.results.length} results`);
            pendingSearches.delete(cacheKey);
            return r.results;
          }
        } catch (err) {
          log.warn(`⚠️ Worker search failed: ${err.message} → CLI fallback`);
        }
      }
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

    // 🚀 v82: prewarm เพลงบนสุด (หลังส่งผลลัพธ์แล้ว — ไม่ทำให้ค้นหาช้าลง)
    if (offset === 0 && CONFIG.PREWARM_ON_SEARCH > 0) {
      prewarm(results.filter((r) => !r.isLive).slice(0, CONFIG.PREWARM_ON_SEARCH).map((r) => r.id));
    }
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
    let retriedExpired = false;
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

      // GVS requires isolated TLS socket per video stream (reusing keep-alive socket causes 403)
      const proxyReq = protocol.get(url, { headers }, (proxyRes) => {
        if (
          proxyRes.statusCode >= 300 &&
          proxyRes.statusCode < 400 &&
          proxyRes.headers.location
        ) {
          proxyRes.resume();
          log.info(`↪️ Redirect [${depth}]`);
          proxyStream(proxyRes.headers.location, depth + 1);
          return;
        }

        // 🚀 v82: URL ใน cache หมดอายุ/ถูกปฏิเสธ → resolve ใหม่ 1 ครั้งอัตโนมัติ
        if ((proxyRes.statusCode === 403 || proxyRes.statusCode === 410) && !retriedExpired) {
          retriedExpired = true;
          proxyRes.resume();
          log.warn(`🔁 Upstream ${proxyRes.statusCode} for ${videoId} — re-resolving`);
          urlCache.delete(videoId);
          resolveAudioUrl(videoId, "high")
            .then((fresh) => {
              if (fresh && fresh.url && !res.headersSent) proxyStream(fresh.url, 0);
              else if (!res.headersSent) res.status(502).json({ error: "Stream unavailable" });
            })
            .catch(() => {
              if (!res.headersSent) res.status(502).json({ error: "Stream unavailable" });
            });
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

    // 🚀 v82: ใช้ worker pool (priority ต่ำ) แบบขนาน — คิวจัดการโหลดเอง
    await Promise.all(
      batch.map(async (videoId) => {
        try {
          const resolved = await resolveAudioUrl(videoId, "low");
          if (resolved) {
            const streamProxyUrl = `${protocol}://${host}/api/stream/${videoId}`;
            results[videoId] = (resolved.isLive || resolved.isHls) ? resolved.url : streamProxyUrl;
          } else {
            results[videoId] = null;
          }
        } catch {
          results[videoId] = null;
        }
      }),
    );

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
// ============================================
// 🚀 v82: API: Prewarm (fire-and-forget)
// POST /api/prewarm  Body: { videoIds: ["id1", ...] }
// แอปเรียกตอนนิ้วแตะเพลง / ตอนเปิดแอป เพื่อให้ server resolve ไว้ก่อน
// ============================================
app.post("/api/prewarm", (req, res) => {
  const { videoIds } = req.body || {};
  if (!Array.isArray(videoIds)) {
    return res.status(400).json({ error: "Missing videoIds array" });
  }
  const queued = prewarm(videoIds.slice(0, 10));
  res.status(202).json({ queued });
});

app.get("/health", (req, res) => res.json({ status: "ok" }));
app.get("/api/health", async (req, res) => {
  try {
    const version = await runYtDlp(["--version"]);
    res.json({
      status: "ok",
      server_version: "v82",
      ytdlp_version: version,
      url_cache_size: urlCache.size,
      search_cache_size: searchCache.size,
      active_ytdlp: _activeYtDlp,
      queued_ytdlp: _ytDlpQueue.length,
      pool: {
        size: CONFIG.POOL_SIZE,
        ready: pool.readyCount,
        queued_high: pool.high.length,
        queued_low: pool.low.length,
        ...pool.stats,
      },
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
