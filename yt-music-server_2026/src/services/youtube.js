const { execFile } = require('child_process');
const { getOrSet } = require('./cache');

const YT_DLP_PATH = process.env.YT_DLP_PATH || 'yt-dlp';
const MAX_CONCURRENT_YTDLP = parseInt(process.env.MAX_CONCURRENT_YTDLP || '2', 10);
const CACHE_TTL = 25 * 60 * 1000;       // 25 min for normal URLs
const LIVE_CACHE_TTL = 3 * 60 * 1000;   // 3 min for live URLs

// ---- Semaphore — limit concurrent yt-dlp processes on QNAP ----
let _activeYtDlp = 0;
const _ytDlpQueue = [];

function acquireSemaphore() {
  return new Promise((resolve) => {
    if (_activeYtDlp < MAX_CONCURRENT_YTDLP) {
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
    next();
  } else {
    _activeYtDlp--;
  }
}

// ---- Pending resolutions (request coalescing) ----
const pendingResolutions = new Map();

/**
 * Execute yt-dlp with given arguments
 * @param {string[]} args
 * @returns {Promise<string>}
 */
function runYtDlp(args) {
  return new Promise((resolve, reject) => {
    const options = {
      maxBuffer: 10 * 1024 * 1024,
      timeout: 30000,
      env: { ...process.env, PYTHONIOENCODING: 'utf-8' },
    };
    execFile(YT_DLP_PATH, args, options, (err, stdout, stderr) => {
      if (err) {
        console.error(`[yt-dlp error] ${stderr || err.message}`);
        return reject(new Error(stderr || err.message));
      }
      resolve(stdout.trim());
    });
  });
}

/**
 * Run yt-dlp with semaphore to limit concurrent processes
 */
async function runYtDlpLimited(args) {
  await acquireSemaphore();
  try {
    return await runYtDlp(args);
  } finally {
    releaseSemaphore();
  }
}

/**
 * Search YouTube for videos
 * @param {string} query
 * @param {number} limit
 * @returns {Promise<Object[]>}
 */
async function search(query, limit = 20) {
  const cacheKey = `search:${query}:${limit}`;
  return getOrSet(cacheKey, async () => {
    const raw = await runYtDlp([
      `ytsearch${limit}:${query}`,
      '--dump-json',
      '--flat-playlist',
      '--no-warnings',
      '--default-search', 'ytsearch',
    ]);

    const results = raw
      .split('\n')
      .filter(Boolean)
      .map(line => {
        try { return JSON.parse(line); }
        catch { return null; }
      })
      .filter(Boolean)
      .map(formatSearchResult);

    return results;
  });
}

/**
 * Get video/audio info
 * @param {string} videoId
 * @returns {Promise<Object>}
 */
async function getInfo(videoId) {
  const cacheKey = `info:${videoId}`;
  return getOrSet(cacheKey, async () => {
    const raw = await runYtDlp([
      `https://www.youtube.com/watch?v=${videoId}`,
      '--dump-json',
      '--no-warnings',
      '--no-playlist',
    ]);
    const data = JSON.parse(raw);
    return formatVideoInfo(data);
  });
}

/**
 * Get direct audio stream URL
 * @param {string} videoId
 * @param {string} quality - 'low' | 'medium' | 'high'
 * @returns {Promise<Object>} { url, mimeType, filesize, duration }
 */
async function getStreamUrl(videoId, quality = 'medium') {
  const cacheKey = `stream:${videoId}:${quality}`;
  return getOrSet(cacheKey, async () => {
    const qualityMap = {
      low: 'worstaudio',
      medium: 'bestaudio[abr<=128]',
      high: 'bestaudio',
    };
    const formatSpec = qualityMap[quality] || qualityMap.medium;

    const raw = await runYtDlp([
      `https://www.youtube.com/watch?v=${videoId}`,
      '-f', formatSpec,
      '--dump-json',
      '--no-warnings',
      '--no-playlist',
    ]);

    const data = JSON.parse(raw);
    const audioUrl = data.url || data.requested_formats?.[0]?.url;

    return {
      url: audioUrl,
      mimeType: data.acodec === 'opus' ? 'audio/webm' : 'audio/mp4',
      filesize: data.filesize || data.filesize_approx || null,
      duration: data.duration,
      title: data.title,
      artist: data.artist || data.uploader || data.channel,
    };
  }, 300000); // Cache stream URLs for 5 min (they expire)
}

/**
 * Get download URL for MP3
 * @param {string} videoId
 * @returns {Promise<Object>}
 */
async function getDownloadUrl(videoId) {
  const raw = await runYtDlp([
    `https://www.youtube.com/watch?v=${videoId}`,
    '-f', 'bestaudio',
    '--dump-json',
    '--no-warnings',
    '--no-playlist',
  ]);

  const data = JSON.parse(raw);
  return {
    url: data.url || data.requested_formats?.[0]?.url,
    title: data.title,
    artist: data.artist || data.uploader || data.channel,
    duration: data.duration,
    thumbnail: data.thumbnail,
  };
}

/**
 * Get playlist items
 * @param {string} playlistId
 * @returns {Promise<Object>}
 */
async function getPlaylist(playlistId) {
  const cacheKey = `playlist:${playlistId}`;
  return getOrSet(cacheKey, async () => {
    const raw = await runYtDlp([
      `https://www.youtube.com/playlist?list=${playlistId}`,
      '--dump-json',
      '--flat-playlist',
      '--no-warnings',
    ]);

    const items = raw
      .split('\n')
      .filter(Boolean)
      .map(line => {
        try { return JSON.parse(line); }
        catch { return null; }
      })
      .filter(Boolean)
      .map(formatSearchResult);

    return {
      playlistId,
      count: items.length,
      items,
    };
  });
}

/**
 * Get related videos
 * @param {string} videoId
 * @returns {Promise<Object[]>}
 */
async function getRelated(videoId) {
  // Use YouTube's "related" by searching with the video title
  const info = await getInfo(videoId);
  const query = `${info.title} ${info.artist || ''}`.trim();
  const results = await search(query, 15);
  // Filter out the original video
  return results.filter(r => r.videoId !== videoId).slice(0, 10);
}

/**
 * Get trending music
 * @param {string} region
 * @returns {Promise<Object[]>}
 */
async function getTrending(region = 'TH') {
  const cacheKey = `trending:${region}`;
  return getOrSet(cacheKey, async () => {
    const raw = await runYtDlp([
      `https://music.youtube.com/charts`,
      '--dump-json',
      '--flat-playlist',
      '--no-warnings',
      '--playlist-end', '20',
      '--geo-bypass-country', region,
    ]);

    const results = raw
      .split('\n')
      .filter(Boolean)
      .map(line => {
        try { return JSON.parse(line); }
        catch { return null; }
      })
      .filter(Boolean)
      .map(formatSearchResult);

    return results;
  }, 1800000); // Cache trending for 30 min
}

/**
 * Get search suggestions
 * @param {string} query
 * @returns {Promise<string[]>}
 */
async function getSuggestions(query) {
  const cacheKey = `suggestions:${query}`;
  return getOrSet(cacheKey, async () => {
    // Use YouTube's suggestion API (public)
    const fetch = require('node-fetch');
    const res = await fetch(
      `https://suggestqueries-clients6.youtube.com/complete/search?client=youtube&ds=yt&q=${encodeURIComponent(query)}`,
      { headers: { 'User-Agent': 'Mozilla/5.0' } }
    );
    const text = await res.text();
    // Parse JSONP response
    const match = text.match(/\[.*\]/s);
    if (!match) return [];
    const data = JSON.parse(match[0]);
    if (!Array.isArray(data[1])) return [];
    return data[1].map(item => (Array.isArray(item) ? item[0] : item)).slice(0, 10);
  });
}

// ---- Formatters ----

function formatSearchResult(item) {
  const cleanId = item.id || item.url?.match(/v=([^&]+)/)?.[1] || item.url || '';
  const dur = typeof item.duration === 'number' ? item.duration : (parseInt(item.duration, 10) || 0);
  const isLive = item.is_live || dur === 0 || item.duration === 'None' || !item.duration;
  const thumb = item.thumbnail || item.thumbnails?.[0]?.url || (cleanId ? `https://i.ytimg.com/vi/${cleanId}/mqdefault.jpg` : '');

  return {
    id: cleanId,
    videoId: cleanId,
    title: item.title || 'ไม่ระบุชื่อเพลง',
    artist: item.artist || item.uploader || item.channel || 'ไม่ระบุชื่อศิลปิน',
    duration: dur,
    durationString: item.duration_string || formatDuration(dur),
    thumbnail: thumb,
    viewCount: item.view_count || null,
    isLive: Boolean(isLive),
  };
}

function formatVideoInfo(data) {
  const cleanId = data.id || '';
  const dur = typeof data.duration === 'number' ? data.duration : (parseInt(data.duration, 10) || 0);
  const isLive = data.is_live || dur === 0 || data.duration === 'None' || !data.duration;
  const thumb = data.thumbnail || (cleanId ? `https://i.ytimg.com/vi/${cleanId}/mqdefault.jpg` : '');

  return {
    id: cleanId,
    videoId: cleanId,
    title: data.title || 'ไม่ระบุชื่อเพลง',
    artist: data.artist || data.uploader || data.channel || 'ไม่ระบุชื่อศิลปิน',
    album: data.album || null,
    duration: dur,
    durationString: data.duration_string || formatDuration(dur),
    thumbnail: thumb,
    thumbnails: data.thumbnails || [],
    viewCount: data.view_count || 0,
    uploadDate: data.upload_date || null,
    description: data.description?.slice(0, 500) || null,
    isLive: Boolean(isLive),
  };
}

function formatDuration(seconds) {
  if (!seconds) return null;
  const m = Math.floor(seconds / 60);
  const s = seconds % 60;
  return `${m}:${String(s).padStart(2, '0')}`;
}

/**
 * Resolve audio URL for a video (with Live/HLS detection)
 * Used by Flutter app — returns direct URL instead of proxying
 * Includes request coalescing to avoid duplicate yt-dlp calls
 * @param {string} videoId
 * @returns {Promise<Object|null>} { url, isLive, isHls }
 */
async function resolveAudioUrl(videoId) {
  // 1. Check cache
  const cacheKey = `resolve:${videoId}`;
  const { cache } = require('./cache');
  const cached = cache.get(cacheKey);
  if (cached) return cached;

  // 2. Check if already resolving (request coalescing)
  if (pendingResolutions.has(videoId)) {
    return pendingResolutions.get(videoId);
  }

  // 3. Resolve using yt-dlp
  const resolutionPromise = (async () => {
    try {
      const infoArgs = [
        `https://www.youtube.com/watch?v=${videoId}`,
        '--no-warnings',
        '--no-playlist',
        '--no-check-certificates',
        '--no-cache-dir',
        '--extractor-args', 'youtube:player_client=android,web,mweb',
        '--print',
        '%(is_live)s\t%(live_status)s\t%(url)s\t%(hls_manifest_url)s',
        '-f',
        'bestaudio/best',
      ];

      let output = await runYtDlpLimited(infoArgs);
      output = output.split('\n')[0].trim();
      const parts = output.split('\t');

      const rawIsLive = parts[0] || '';
      const liveStatus = parts[1] || '';
      const directUrl = (parts[2] || '').trim();
      const hlsUrl = (parts[3] || '').trim();

      const isLive = rawIsLive === 'True' || liveStatus === 'is_live' || liveStatus === 'is_upcoming';
      const isHls = isLive && hlsUrl && hlsUrl.startsWith('http');
      const finalUrl = isHls ? hlsUrl : directUrl;

      if (finalUrl) {
        const ttl = isLive ? LIVE_CACHE_TTL : CACHE_TTL;
        const result = { url: finalUrl, isLive, isHls };
        cache.set(cacheKey, result, { ttl });
        return result;
      }
      return null;
    } catch (err) {
      console.error(`[resolveAudioUrl] Failed for ${videoId}:`, err.message);
      return null;
    } finally {
      pendingResolutions.delete(videoId);
    }
  })();

  pendingResolutions.set(videoId, resolutionPromise);
  return resolutionPromise;
}

/**
 * Get semaphore stats
 */
function getSemaphoreStats() {
  return {
    active: _activeYtDlp,
    queued: _ytDlpQueue.length,
    max: MAX_CONCURRENT_YTDLP,
  };
}

module.exports = {
  search,
  getInfo,
  getStreamUrl,
  getDownloadUrl,
  getPlaylist,
  getRelated,
  getTrending,
  getSuggestions,
  resolveAudioUrl,
  getSemaphoreStats,
};

