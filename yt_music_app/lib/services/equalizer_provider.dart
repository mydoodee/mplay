import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio/just_audio.dart';
import 'audio_handler.dart';

class EqualizerProvider extends ChangeNotifier {
  final MyAudioHandler audioHandler;

  bool _isEqualizerEnabled = true;
  String _selectedPreset = 'normal';
  double _bassBoosterLevel = 0.0;

  // 7 bands: 40Hz, 150Hz, 400Hz, 1.2kHz, 3kHz, 5kHz, 12kHz
  List<double> _bandValues = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
  List<double> _customBandValues = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];

  // ── Hardware EQ range (queried from Android at runtime) ──
  double _hwMinGain = -15.0; // fallback
  double _hwMaxGain = 15.0;  // fallback
  int _hwBandCount = 5;      // Android typically has 5 bands
  bool _hwRangeQueried = false;

  final List<String> presets = [
    'normal',
    'pop',
    'classic',
    'jazz',
    'rock',
    'custom',
  ];
  final List<String> bands = ['40', '150', '400', '1.2K', '3K', '5K', '12K'];

  bool get isEqualizerEnabled => _isEqualizerEnabled;
  String get selectedPreset => _selectedPreset;
  double get bassBoosterLevel => _bassBoosterLevel;
  List<double> get bandValues => _bandValues;

  // ── Mutex for Audio Thread Protection ──
  bool _isApplying = false;
  bool _pendingApply = false;
  Timer? _applyDebounce;

  EqualizerProvider(this.audioHandler) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isEqualizerEnabled = prefs.getBool('eq_enabled') ?? true;
    _selectedPreset = prefs.getString('eq_preset') ?? 'normal';

    // Migrate old Thai presets if found
    if (_selectedPreset == 'ปกติ') {
      _selectedPreset = 'normal';
    } else if (_selectedPreset == 'ป๊อป') {
      _selectedPreset = 'pop';
    } else if (_selectedPreset == 'ร็อก') {
      _selectedPreset = 'rock';
    } else if (_selectedPreset == 'แจ๊ส') {
      _selectedPreset = 'jazz';
    } else if (_selectedPreset == 'คลาสสิก') {
      _selectedPreset = 'classic';
    } else if (_selectedPreset == 'กำหนดเอง') {
      _selectedPreset = 'custom';
    }

    _bassBoosterLevel = prefs.getDouble('eq_bass_boost') ?? 0.0;

    final savedBands = prefs.getString('eq_bands');
    if (savedBands != null) {
      final List<dynamic> decoded = jsonDecode(savedBands);
      final loaded = decoded.map((e) => (e as num).toDouble()).toList();
      if (loaded.length == 7) {
        // Clamp old saved values to new safe range
        _bandValues = loaded.map((v) => v.clamp(-12.0, 12.0)).toList();
      }
    }

    final savedCustom = prefs.getString('eq_custom_bands');
    if (savedCustom != null) {
      final List<dynamic> decodedCustom = jsonDecode(savedCustom);
      final loadedCustom = decodedCustom
          .map((e) => (e as num).toDouble())
          .toList();
      if (loadedCustom.length == 7) {
        _customBandValues = loadedCustom.map((v) => v.clamp(-12.0, 12.0)).toList();
      }
    }

    // Apply preset values if not custom (override saved bands with clean preset)
    if (_selectedPreset != 'custom') {
      _bandValues = _getPresetValues(_selectedPreset);
    }

    notifyListeners();
    _applyToAudioPlayer();
  }

  /// Get clean preset values — kept moderate to avoid clipping
  List<double> _getPresetValues(String preset) {
    switch (preset) {
      case 'pop':
        // Bright vocals, gentle bass, sparkle on top
        return [2.5, 1.5, -1.0, -1.5, -0.5, 2.0, 3.0];
      case 'rock':
        // Strong bass & treble, slightly scooped mids
        return [4.0, 3.0, -0.5, 0.5, 2.0, 3.5, 4.0];
      case 'jazz':
        // Warm bass, smooth mids, gentle highs
        return [3.5, 2.5, 1.0, -0.5, -0.5, 1.5, 2.5];
      case 'classic':
        // Balanced, mild boost across the board
        return [3.0, 2.0, 0.5, -0.5, 1.0, 2.0, 3.0];
      case 'normal':
      default:
        return [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('eq_enabled', _isEqualizerEnabled);
    await prefs.setString('eq_preset', _selectedPreset);
    await prefs.setDouble('eq_bass_boost', _bassBoosterLevel);
    await prefs.setString('eq_bands', jsonEncode(_bandValues));
    await prefs.setString('eq_custom_bands', jsonEncode(_customBandValues));
  }

  /// Save + apply (for preset changes, toggle, etc.)
  Future<void> _saveAndApply() async {
    await _saveSettings();
    _applyToAudioPlayer();
  }

  // ── Throttle: apply audio at most once every 250ms during dragging ──
  // This prevents gain from "jumping" (old → new) which causes clicks/noise
  // Instead, gain changes gradually in small steps while the user drags
  DateTime _lastApplyTime = DateTime(2000);
  Timer? _throttleTimer;
  static const _throttleMs = 250;

  /// Throttled apply — sends gain to audio engine during dragging
  /// Max 1 update per 250ms to keep it smooth without overloading
  void _throttledApply() {
    final now = DateTime.now();
    final elapsed = now.difference(_lastApplyTime).inMilliseconds;

    if (elapsed >= _throttleMs) {
      // Enough time has passed → apply immediately
      _lastApplyTime = now;
      _throttleTimer?.cancel();
      _applyToAudioPlayer();
    } else {
      // Too soon → schedule apply at the end of the throttle window
      _throttleTimer?.cancel();
      _throttleTimer = Timer(
        Duration(milliseconds: _throttleMs - elapsed),
        () {
          _lastApplyTime = DateTime.now();
          _applyToAudioPlayer();
        },
      );
    }
  }

  void setEnabled(bool enabled) {
    _isEqualizerEnabled = enabled;
    notifyListeners();
    _saveAndApply();
  }

  void setPreset(String preset) {
    _selectedPreset = preset;
    if (preset == 'custom') {
      _bandValues = List.from(_customBandValues);
    } else {
      _bandValues = _getPresetValues(preset);
    }
    notifyListeners();
    _saveAndApply();
  }

  /// ระหว่างลากนิ้ว — อัปเดต UI + ส่งค่าไป audio engine แบบ throttle
  /// ทำให้ gain เปลี่ยนทีละน้อยอย่างนุ่มนวล ไม่กระโดด
  void setBandValueVisual(int index, double value) {
    _bandValues[index] = value;
    _customBandValues[index] = value;
    _selectedPreset = 'custom';
    notifyListeners();
    _throttledApply(); // ← ส่งไป audio engine ด้วย (throttled)
  }

  /// ปล่อยนิ้ว — apply ค่าสุดท้าย + save
  void commitBandValue(int index, double value) {
    _bandValues[index] = value;
    _customBandValues[index] = value;
    _selectedPreset = 'custom';
    _throttleTimer?.cancel();
    notifyListeners();
    _saveAndApply();
  }

  /// ระหว่างลากนิ้ว Bass Booster — อัปเดต UI + throttle apply
  void setBassBoosterVisual(double value) {
    _bassBoosterLevel = value;
    notifyListeners();
    _throttledApply(); // ← ส่งไป audio engine ด้วย (throttled)
  }

  /// ปล่อยนิ้ว Bass Booster — apply ค่าสุดท้าย + save
  void commitBassBooster(double value) {
    _bassBoosterLevel = value;
    _throttleTimer?.cancel();
    notifyListeners();
    _saveAndApply();
  }

  bool _effectsInitialized = false;

  // ── Cached parameters to avoid querying on every apply ──
  AndroidEqualizerParameters? _cachedParameters;

  /// Map 7 UI bands to actual hardware band count (usually 5)
  /// UI bands: [40, 150, 400, 1.2K, 3K, 5K, 12K]
  /// Android typical 5 bands: [60, 230, 910, 3600, 14000] Hz
  /// Mapping: simple nearest-neighbor blend to keep sound natural
  List<double> _mapToHardwareBands(List<double> uiBands) {
    if (_hwBandCount >= 7) {
      return uiBands.take(_hwBandCount).toList();
    }

    if (_hwBandCount == 5) {
      // Map 7 UI bands → 5 hardware bands
      // Use dominant band with gentle blending to keep sound natural
      return [
        uiBands[0] * 0.8 + uiBands[1] * 0.2,   // Sub-bass dominant
        uiBands[1] * 0.6 + uiBands[2] * 0.4,   // Bass-LowMid
        uiBands[3],                               // Mid — map directly
        uiBands[4] * 0.6 + uiBands[5] * 0.4,   // HighMid-Treble
        uiBands[5] * 0.2 + uiBands[6] * 0.8,   // Brilliance dominant
      ];
    }

    // Generic fallback: linear interpolation
    final result = <double>[];
    for (int i = 0; i < _hwBandCount; i++) {
      final ratio = i / (_hwBandCount - 1) * (uiBands.length - 1);
      final low = ratio.floor();
      final high = ratio.ceil().clamp(0, uiBands.length - 1);
      final frac = ratio - low;
      result.add(uiBands[low] * (1 - frac) + uiBands[high] * frac);
    }
    return result;
  }

  /// Clamp gain to hardware range
  double _safeGain(double gain) {
    return gain.clamp(_hwMinGain, _hwMaxGain);
  }

  /// Gentle anti-clipping — only activates when boost is extreme
  /// Threshold is generous (avg > 6 dB) to keep natural sound
  List<double> _antiClip(List<double> gains) {
    double maxBoost = 0;
    for (final g in gains) {
      if (g > maxBoost) maxBoost = g;
    }
    // Only reduce if any single band exceeds safe range
    if (maxBoost <= 8.0) return gains;

    final scale = 8.0 / maxBoost;
    return gains.map((g) => g * scale).toList();
  }

  Future<void> _applyToAudioPlayer() async {
    // ── Mutex Lock Gatekeeper ──
    if (_isApplying) {
      _pendingApply = true;
      return;
    }
    _isApplying = true;
    _pendingApply = false;

    if (!Platform.isAndroid) {
      _isApplying = false;
      return;
    }

    final eq = audioHandler.equalizer;
    final loudness = audioHandler.loudnessEnhancer;

    try {
      // ── Initialize once — keep effects always enabled ──
      if (!_effectsInitialized) {
        try {
          await eq.setEnabled(true);
          await loudness.setEnabled(true);
          _effectsInitialized = true;
        } catch (_) {}
      }

      // ── Query & cache hardware range once ──
      if (!_hwRangeQueried) {
        try {
          _cachedParameters = await eq.parameters;
          _hwMinGain = _cachedParameters!.minDecibels;
          _hwMaxGain = _cachedParameters!.maxDecibels;
          _hwBandCount = _cachedParameters!.bands.length;
          _hwRangeQueried = true;
          debugPrint("🎛️ EQ Hardware: bands=$_hwBandCount, "
              "range=[$_hwMinGain, $_hwMaxGain] dB");
        } catch (e) {
          debugPrint("⚠️ Could not query EQ range: $e");
        }
      }

      // Determine target values based on whether EQ is globally enabled
      final double targetBass = _isEqualizerEnabled ? _bassBoosterLevel : 0.0;
      final List<double> targetBands = _isEqualizerEnabled
          ? _bandValues
          : List.filled(_bandValues.length, 0.0);

      // ── Map & prepare all gain values first ──
      final hwGains = _mapToHardwareBands(targetBands);
      final safeGains = _antiClip(hwGains);
      final bassGainDb = targetBass / 100.0 * 10.0;

      // ── Apply ALL changes in parallel (atomic update) ──
      // This prevents the audio stutter from sequential band-by-band updates
      final parameters = _cachedParameters ?? await eq.parameters;
      _cachedParameters = parameters;
      final bandsList = parameters.bands;

      final futures = <Future>[];

      // Bass booster
      futures.add(
        loudness.setTargetGain(bassGainDb).catchError((e) {
          debugPrint("LoudnessEnhancer error: $e");
        }),
      );

      // All EQ bands at once
      for (int i = 0; i < min(bandsList.length, safeGains.length); i++) {
        final clampedGain = _safeGain(safeGains[i]);
        futures.add(
          bandsList[i].setGain(clampedGain).catchError((e) {
            debugPrint("Band $i error: $e");
          }),
        );
      }

      // Fire all platform channel calls simultaneously
      await Future.wait(futures);

    } catch (e) {
      if (kDebugMode) {
        print("Equalizer not supported or failed: $e");
      }
    } finally {
      _isApplying = false;
      if (_pendingApply) {
        // Small delay before processing pending apply
        // to let audio engine settle
        Future.delayed(const Duration(milliseconds: 50), () {
          _applyToAudioPlayer();
        });
      }
    }
  }

  @override
  void dispose() {
    _applyDebounce?.cancel();
    super.dispose();
  }
}
