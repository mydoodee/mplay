const https = require('https');
const { getOrSet } = require('./cache');

const LYRICS_SOURCES = [
  { name: 'lrclib', search: searchLrcLib },
];

/**
 * Fetch helper with fallback to https module
 */
function safeFetch(url) {
  if (typeof fetch === 'function') {
    return fetch(url, {
      headers: {
        'User-Agent': 'yt-music-server/2.0.0 (https://github.com/yt-music-server)',
      },
    }).then(res => res.json());
  }

  return new Promise((resolve, reject) => {
    https.get(url, {
      headers: {
        'User-Agent': 'yt-music-server/2.0.0 (https://github.com/yt-music-server)',
      },
    }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch (e) {
          resolve(null);
        }
      });
    }).on('error', reject);
  });
}

/**
 * Search for lyrics
 * @param {string} query - Song title + artist
 * @returns {Promise<Object|null>}
 */
async function findLyrics(query) {
  const cacheKey = `lyrics:${query}`;
  return getOrSet(cacheKey, async () => {
    for (const source of LYRICS_SOURCES) {
      try {
        const result = await source.search(query);
        if (result) return result;
      } catch (err) {
        console.error(`[lyrics] ${source.name} error:`, err.message);
      }
    }
    return null;
  }, 3600000); // Cache lyrics for 1 hour
}

/**
 * Search LrcLib (free, no API key)
 * @param {string} query
 * @returns {Promise<Object|null>}
 */
async function searchLrcLib(query) {
  const data = await safeFetch(
    `https://lrclib.net/api/search?q=${encodeURIComponent(query)}`
  );

  if (!data || !Array.isArray(data) || data.length === 0) return null;

  const best = data[0];
  return {
    title: best.trackName || best.name || query,
    artist: best.artistName || 'Unknown',
    album: best.albumName || null,
    duration: best.duration || null,
    plainLyrics: best.plainLyrics || null,
    syncedLyrics: best.syncedLyrics || null,
    source: 'lrclib',
  };
}

module.exports = { findLyrics };
