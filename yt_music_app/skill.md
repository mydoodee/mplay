# Agent Skills Manual (skill.md)

This manual outlines operational guidelines (skills) for coding agents to perform common tasks in the `yt_music_app` repository safely and consistently.

---

## 🛠️ Skill 1: Upgrading App Version (OTA Update System)

The app features an in-app updater. When updating the app version, you **must** update two places simultaneously:

### Step 1: Update pubspec.yaml
Locate [pubspec.yaml](file:///Users/porawat.chi/gzon/mplay/yt_music_app/pubspec.yaml) and bump the version string and build number:
```yaml
version: 1.0.1+64 # Update the minor version + build number
```

### Step 2: Update version.json
Locate the remote configuration file (usually stored locally at `version.json` or downloaded folder, e.g., `/Users/porawat.chi/Downloads/version.json`):
```json
{
  "latest_version": "1.0.1.64",
  "build_number": 64,
  "download_url": "https://music.growkub.com/mplay-1.0.1.64.apk",
  "release_notes": "• ปรับปรุงหน้าจอ Equalizer \n"
}
```
*Make sure `latest_version` and `build_number` match the `pubspec.yaml` release number exactly so the client application detects the update.*

---

## 🎵 Skill 2: Troubleshooting Audio Playback Issues

If remote streams stop playing or freeze:

1. **Verify user headers**: Stream URLs from YouTube require a `'User-Agent': 'Mozilla/5.0'` header. Check this in `audio_handler.dart`.
2. **Check HLS / Live Stream configuration**: For live streams (duration is 0 or `isLive == true`), disable GZIP decompression by setting the header `'Accept-Encoding': 'identity'` to avoid ExoPlayer manifest load failures.
3. **Debug stuck loading**:
   * Inspect the `_loadingWatchdog` in `lib/services/audio_handler.dart`.
   * Check the `_maxSongFailures` circuit breaker to see if consecutive loading errors are skipping valid songs by accident.

---

## 🎛️ Skill 3: Modifying Equalizer Settings & Presets

When editing EQ profiles or ranges:

### Step 1: Update Logic
In [equalizer_provider.dart](file:///Users/porawat.chi/gzon/mplay/yt_music_app/lib/services/equalizer_provider.dart):
* Edit preset vectors in `_getPresetValues(String preset)` (corresponding to the 7 bands: 40Hz, 150Hz, 400Hz, 1.2kHz, 3kHz, 5kHz, 12kHz).
* Keep the range clamped to `[-10.0, 10.0]` or your target limits.

### Step 2: Update UI Sliders
In [equalizer_screen.dart](file:///Users/porawat.chi/gzon/mplay/yt_music_app/lib/screens/equalizer_screen.dart):
* Match `min` and `max` limits in the `Slider` widget.
* Recalculate `percent` (used for drawing the volcanic glowing track):
  $$\text{percent} = \frac{\text{value} - \text{min}}{\text{max} - \text{min}}$$

---

## 🚀 Skill 4: Launching Emulators & Compiling

Before pushing changes, run local compilation checks:

1. **List Emulators**:
   ```bash
   flutter emulators
   ```
2. **Launch Target Emulator**:
   ```bash
   flutter emulators --launch <emulator_id>
   ```
3. **Static Analysis Check**:
   ```bash
   flutter analyze
   ```
   *Verify there are no "error" level issues introduced.*
4. **Compile Run**:
   ```bash
   flutter run
   ```
