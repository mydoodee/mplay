const DEFAULT_TTL = parseInt(process.env.CACHE_TTL_SECONDS || '600', 10) * 1000;
const MAX_ITEMS = parseInt(process.env.CACHE_MAX_ITEMS || '500', 10);

let cache;

try {
  const { LRUCache } = require('lru-cache');
  cache = new LRUCache({
    max: MAX_ITEMS,
    ttl: DEFAULT_TTL,
    allowStale: false,
    updateAgeOnGet: true,
  });
} catch (e) {
  // Built-in Map-based cache fallback (Zero external dependency)
  class SimpleCache {
    constructor(max, ttl) {
      this.max = max;
      this.ttl = ttl;
      this.store = new Map();
    }
    get(key) {
      const entry = this.store.get(key);
      if (!entry) return undefined;
      if (Date.now() > entry.expiry) {
        this.store.delete(key);
        return undefined;
      }
      return entry.val;
    }
    set(key, val, options = {}) {
      const ttl = options.ttl || this.ttl;
      if (this.store.size >= this.max) {
        const firstKey = this.store.keys().next().value;
        if (firstKey) this.store.delete(firstKey);
      }
      this.store.set(key, { val, expiry: Date.now() + ttl });
    }
    delete(key) {
      this.store.delete(key);
    }
    clear() {
      this.store.clear();
    }
    get size() {
      return this.store.size;
    }
  }
  cache = new SimpleCache(MAX_ITEMS, DEFAULT_TTL);
}

/**
 * Get a cached value or compute it
 * @param {string} key - Cache key
 * @param {Function} fetcher - Async function to compute value if not cached
 * @param {number} [ttl] - Override TTL in ms
 * @returns {Promise<any>}
 */
async function getOrSet(key, fetcher, ttl) {
  const cached = cache.get(key);
  if (cached !== undefined) {
    return cached;
  }
  const value = await fetcher();
  cache.set(key, value, { ttl: ttl || DEFAULT_TTL });
  return value;
}

function invalidate(key) {
  cache.delete(key);
}

function stats() {
  return {
    size: cache.size,
    maxSize: MAX_ITEMS,
    ttlMs: DEFAULT_TTL,
  };
}

function clear() {
  cache.clear();
}

module.exports = { cache, getOrSet, invalidate, stats, clear };
