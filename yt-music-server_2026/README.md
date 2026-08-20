# M-PLAY Backend Server (2026 Edition) 🎵

High-performance YouTube Music API and Streaming Gateway for **M-PLAY** Flutter App and Android Automotive / Head Units, optimized for QNAP NAS (Container Station / Docker / PM2).

---

## 🌟 Key Features
- **⚡ Zero-Drop Audio Streaming**: Proxies audio streams directly from YouTube CDN via native Node.js chunk pipes with `200 OK` (Standard) & `206 Partial Content` (Range seek) support.
- **🛡️ Concurrency Semaphore Protection**: Limits simultaneous `yt-dlp` spawn processes to 2, preventing CPU spikes on QNAP / low-spec servers.
- **🚀 Dual-Layer In-Memory Cache**: Built-in Map cache with TTL for search queries (10 mins) and resolved streaming URLs (25 mins).
- **🎙️ AI Voice Search**: Native Groq Whisper AI transcription fallback (`/api/speech-to-text`) for voice searching on car head units.
- **📦 Batch Pre-Resolution**: Sequentially resolves upcoming playlist tracks (`/api/audio-urls`) to enable zero-latency gapless song switching.
- **📱 Static OTA Updates**: Hosts `.apk` updates and `version.json` for in-app update checks.
- **📡 HLS & Live Stream Proxying**: Live broadcast support with proper Apple MPEGURL (`.m3u8`) headers for Android ExoPlayer.

---

## 📡 API Endpoints

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/health` / `/api/health` | Server status, `yt-dlp` version & cache metrics |
| `GET` | `/api/search?q={query}` | Search songs and artists on YouTube |
| `GET` | `/api/audio-url/:videoId` | Get streaming proxy URL for a track |
| `POST` | `/api/audio-urls` | Batch pre-resolve multiple video IDs |
| `GET` | `/api/stream/:videoId` | High-fidelity audio stream proxy |
| `GET` | `/api/info/:videoId` | Song metadata (title, duration, views) |
| `POST` | `/api/speech-to-text` | Groq Whisper speech recognition |
| `POST` | `/api/heartbeat` | Device telemetry heartbeat |
| `GET` | `/version.json` | Latest app version and download URL |

---

## 🚀 Deployment on QNAP Container Station / Docker

### Using Docker Compose
```yaml
version: '3.8'

services:
  yt-music-server:
    build: .
    container_name: yt-music-server
    restart: unless-stopped
    ports:
      - "3456:3456"
    environment:
      - NODE_ENV=production
      - PORT=3456
      - LOG=true
      - GROQ_API_KEY=your_groq_key_here
```

### Run with Docker CLI
```bash
docker build -t yt-music-server:2026 .
docker run -d --name yt-music-server --restart unless-stopped -p 3456:3456 yt-music-server:2026
```

---

## 💻 Local Development
```bash
npm install
node server.js
```
