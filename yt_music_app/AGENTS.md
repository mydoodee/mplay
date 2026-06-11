# Developer & Agent Guidelines (AGENTS.md)

Welcome to the **yt_music_app** documentation. This file provides a comprehensive overview of the project architecture, modules, and coding guidelines for AI agents and human developers.

---

## 📂 Project Structure
```
lib/
├── config/      # App configuration files (API URLs, feature flags)
├── database/   # SQLite helpers for persistence
├── l10n/        # Localization resources (ARB files)
├── models/     # Data classes (Song, Playlist, etc.)
├── screens/    # UI pages (Home, Player, Equalizer, Settings, About)
├── services/   # Core business logic (Audio, Equalizer, API, Updates)
├── utils/      # Helper utilities (formatters, network client)
└── widgets/    # Reusable UI components
```

---

## ⚙️ Core Architectures & Patterns
### 1️⃣ State Management (Provider)
- **SongProvider** ([song_provider.dart](file:///Users/porawat.chi/gzon/mplay/yt_music_app/lib/services/song_provider.dart)) – single source of truth for playback state, queue, and user actions.
- **EqualizerProvider** ([equalizer_provider.dart](file:///Users/porawat.chi/gzon/mplay/yt_music_app/lib/services/equalizer_provider.dart)) – manages hardware equalizer, presets, and Subtractive‑EQ anti‑clipping logic.

### 2️⃣ Audio Engine (just_audio + audio_service)
Implemented in **audio_handler.dart** – combines `just_audio` for playback with `audio_service` for background and notification support.

### 3️⃣ Recovery Mechanisms
- **Direct URL Recovery** – refreshes expired YouTube URLs via `ApiService().getAudioUrl`.
- **Circuit Breaker** – skips tracks after consecutive failures (`_maxSongFailures = 2`).
- **Loading Watchdog** – monitors long buffering times and triggers fallback.

---

## 🎧 Equalizer & DSP Logic
- **Subtractive EQ (Auto‑Attenuation)** – ensures the maximum gain never exceeds 0 dB, preventing digital clipping.
- UI slider range: `[-10.0, 10.0]` dB.
- Preset curves (Normal, Pop, Classic, Jazz, Rock) mapped to industry‑standard values.

---

## 📁 Database Layer
- **db_helper.dart** – SQLite wrapper handling CRUD for songs, playlists, and user preferences. Key methods: `insertSong`, `getAllSongs`, `updatePlaylist`, `clearCache`.

---

## 📦 Models
- **song.dart** – `Song` class (`id`, `title`, `artist`, `duration`, `url`, `albumArt`, …).
- **playlist.dart** – `Playlist` class (list of song IDs, name, metadata).
- Additional models (`artist.dart`, `album.dart`, etc.) follow similar patterns.

---

## 📺 Screens
- **home_screen.dart** – dashboard with recent tracks, playlists, quick actions.
- **player_screen.dart** – full‑screen player, waveform visualizer, controls.
- **equalizer_screen.dart** – 7‑band sliders, preset selector, real‑time spectrum.
- **settings_screen.dart** – OTA update channel, audio output mode, theme selection.
- **about_screen.dart** – app version, update status, credits.

---

## 🛠️ Services
- **song_provider.dart** – playback state and queue management.
- **equalizer_provider.dart** – hardware EQ control and anti‑clip logic.
- **audio_handler.dart** – background playback integration.
- **api_service.dart** – YouTube‑DL wrapper for stream URL fetching and error handling.
- **update_service.dart** – OTA update checks using `version.json`.

---

## 🧰 Utils
- **formatters.dart** – time formatting, string truncation, number conversion.
- **network.dart** – lightweight HTTP client with timeout handling (used by `api_service`).

---

## 🎨 Widgets
- **mini_equalizer.dart** – animated bar visualizer on song tiles.
- **song_tile.dart** – list item displaying song metadata and play button.
- **progress_slider.dart** – gradient‑filled custom slider used throughout the app.
- **preset_selector.dart** – dropdown for EQ preset selection.

---

## ⚙️ Config
- **api_config.dart** – base URLs, API keys, timeout constants.
- **app_config.dart** (optional) – feature flags and environment switches.

## 🚀 Entry Point

- **main.dart** – Application entry point that initializes providers, sets up the `MaterialApp`, and defines the initial route to the Home screen.

---

## 🌐 Localization (l10n)
- ARB files for English, Thai, and other supported languages.
- Accessed via `AppLocalizations.of(context)`.

---

## 🎨 UI Design System
- **Theme**: Molten Lava / Volcanic Glass – deep charcoal backgrounds with glowing orange‑red accents.
- **Controls**: Gradient sliders, micro‑animations (e.g., MiniEqualizer bar, pulsing icons).
- **Animations**: Subtle hover effects and interactive transitions.

---

## 🛡️ Coding Guidelines for Agents
1. **Preserve Comments** – keep existing Thai documentation untouched unless explicitly requested.
2. **Async Safety** – always check `mounted` before using `BuildContext` after async calls.
3. **Audio Integrity** – never bypass `_antiClip`; ensure hardware gain stays ≤ 0 dB.
4. **Offline Support** – rely on `db_helper.dart` for cached data.
5. **Localization** – use `AppLocalizations` for all user‑visible strings.

---

*This document is automatically kept up‑to‑date by AI agents. Regenerate after major architectural changes.*
