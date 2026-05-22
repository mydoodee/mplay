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
  double _hwMinGain = -15.0;
  double _hwMaxGain = 15.0;
  int _hwBandCount = 5;
  bool _hwRangeQueried = false;

  final List<String> presets = [
    'normal', 'pop', 'classic', 'jazz', 'rock', 'custom',
  ];
  final List<String> bands = ['40', '150', '400', '1.2K', '3K', '5K', '12K'];

  bool get isEqualizerEnabled => _isEqualizerEnabled;
  String get selectedPreset => _selectedPreset;
  double get bassBoosterLevel => _bassBoosterLevel;
  List<double> get bandValues => _bandValues;

  // ── Mutex ──
  bool _isApplying = false;
  bool _pendingApply = false;

  EqualizerProvider(this.audioHandler) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isEqualizerEnabled = prefs.getBool('eq_enabled') ?? true;
    _selectedPreset = prefs.getString('eq_preset') ?? 'normal';

    // Migrate old Thai presets
    const thaiMap = {
      'ปกติ': 'normal', 'ป๊อป': 'pop', 'ร็อก': 'rock',
      'แจ๊ส': 'jazz', 'คลาสสิก': 'classic', 'กำหนดเอง': 'custom',
    };
    _selectedPreset = thaiMap[_selectedPreset] ?? _selectedPreset;

    _bassBoosterLevel = prefs.getDouble('eq_bass_boost') ?? 0.0;

    final savedBands = prefs.getString('eq_bands');
    if (savedBands != null) {
      final List<dynamic> decoded = jsonDecode(savedBands);
      final loaded = decoded.map((e) => (e as num).toDouble()).toList();
      if (loaded.length == 7) {
        _bandValues = loaded.map((v) => v.clamp(-3.0, 3.0)).toList();
      }
    }

    final savedCustom = prefs.getString('eq_custom_bands');
    if (savedCustom != null) {
      final List<dynamic> decodedCustom = jsonDecode(savedCustom);
      final loadedCustom = decodedCustom.map((e) => (e as num).toDouble()).toList();
      if (loadedCustom.length == 7) {
        _customBandValues = loadedCustom.map((v) => v.clamp(-3.0, 3.0)).toList();
      }
    }

    if (_selectedPreset != 'custom') {
      _bandValues = _getPresetValues(_selectedPreset);
    }

    notifyListeners();
    // On load: apply directly
    _applyToAudioPlayer();
  }

  List<double> _getPresetValues(String preset) {
    switch (preset) {
      case 'pop':     return [1.25, 0.75, -0.5, -0.75, -0.25, 1.0,  1.5];
      case 'rock':    return [2.0,  1.5,  -0.25, 0.25,  1.0,  1.75, 2.0];
      case 'jazz':    return [1.75, 1.25,  0.5, -0.25, -0.25, 0.75, 1.25];
      case 'classic': return [1.5,  1.0,   0.25, -0.25, 0.5,  1.0,  1.5];
      case 'normal':
      default:        return [0.0,  0.0,   0.0,  0.0,   0.0,  0.0,  0.0];
    }
  }

  List<double> _currentAppliedHwGains = [0.0, 0.0, 0.0, 0.0, 0.0];
  double _currentAppliedBass = 0.0;

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('eq_enabled', _isEqualizerEnabled);
    await prefs.setString('eq_preset', _selectedPreset);
    await prefs.setDouble('eq_bass_boost', _bassBoosterLevel);
    await prefs.setString('eq_bands', jsonEncode(_bandValues));
    await prefs.setString('eq_custom_bands', jsonEncode(_customBandValues));
  }

  Future<void> _saveAndApply() async {
    await _saveSettings();
    _applyToAudioPlayer();
  }

  void setEnabled(bool enabled) {
    _isEqualizerEnabled = enabled;
    notifyListeners();
    _saveAndApply();
  }

  void setPreset(String preset) {
    _selectedPreset = preset;
    _bandValues = preset == 'custom'
        ? List.from(_customBandValues)
        : _getPresetValues(preset);
    notifyListeners();
    _saveAndApply();
  }

  void setBandValueVisual(int index, double value) {
    _bandValues[index] = value;
    _customBandValues[index] = value;
    _selectedPreset = 'custom';
    notifyListeners();
  }

  void commitBandValue(int index, double value) {
    _bandValues[index] = value;
    _customBandValues[index] = value;
    _selectedPreset = 'custom';
    notifyListeners();
    _saveAndApply();
  }

  void setBassBoosterVisual(double value) {
    _bassBoosterLevel = value;
    notifyListeners();
  }

  void commitBassBooster(double value) {
    _bassBoosterLevel = value;
    notifyListeners();
    _saveAndApply();
  }

  // ── Hardware cache ──
  bool _effectsInitialized = false;
  AndroidEqualizerParameters? _cachedParameters;

  List<double> _mapToHardwareBands(List<double> uiBands) {
    if (_hwBandCount >= 7) return uiBands.take(_hwBandCount).toList();

    if (_hwBandCount == 5) {
      return [
        uiBands[0] * 0.8 + uiBands[1] * 0.2,
        uiBands[1] * 0.6 + uiBands[2] * 0.4,
        uiBands[3],
        uiBands[4] * 0.6 + uiBands[5] * 0.4,
        uiBands[5] * 0.2 + uiBands[6] * 0.8,
      ];
    }

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

  double _safeGain(double gain) => gain.clamp(_hwMinGain, _hwMaxGain);

  List<double> _antiClip(List<double> gains) {
    double maxBoost = 0;
    for (final g in gains) {
      if (g > maxBoost) maxBoost = g;
    }
    if (maxBoost <= 6.0) return gains;
    final scale = 6.0 / maxBoost;
    return gains.map((g) => g * scale).toList();
  }

  Future<void> _applyToAudioPlayer() async {
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
      if (!_effectsInitialized) {
        try {
          await eq.setEnabled(true);
          await loudness.setEnabled(true);
          _effectsInitialized = true;
        } catch (_) {}
      }

      if (!_hwRangeQueried) {
        try {
          _cachedParameters = await eq.parameters;
          _hwMinGain = _cachedParameters!.minDecibels;
          _hwMaxGain = _cachedParameters!.maxDecibels;
          _hwBandCount = _cachedParameters!.bands.length;
          _hwRangeQueried = true;
          // Sync size
          _currentAppliedHwGains = List.filled(_hwBandCount, -999.0);
          debugPrint('🎛️ EQ HW: bands=$_hwBandCount, range=[$_hwMinGain, $_hwMaxGain] dB');
        } catch (e) {
          debugPrint('⚠️ EQ range query failed: $e');
        }
      }

      final double targetBass = _isEqualizerEnabled ? _bassBoosterLevel : 0.0;
      final List<double> targetBands = _isEqualizerEnabled
          ? _bandValues
          : List.filled(_bandValues.length, 0.0);

      final hwGains = _antiClip(_mapToHardwareBands(targetBands));
      final targetHwGains = hwGains.map(_safeGain).toList();
      final targetBassDb = targetBass / 100.0 * 10.0;

      final parameters = _cachedParameters ?? await eq.parameters;
      _cachedParameters = parameters;

      // ── Apply ONLY changed bands to prevent MethodChannel flooding & audio zipper noise ──
      final futures = <Future>[];
      for (int i = 0; i < min(parameters.bands.length, targetHwGains.length); i++) {
        if (i >= _currentAppliedHwGains.length) {
          _currentAppliedHwGains.add(-999.0);
        }
        if ((_currentAppliedHwGains[i] - targetHwGains[i]).abs() > 0.05) {
          _currentAppliedHwGains[i] = targetHwGains[i];
          futures.add(parameters.bands[i].setGain(targetHwGains[i]).catchError((_) {}));
        }
      }
      
      if ((_currentAppliedBass - targetBassDb).abs() > 0.05) {
        _currentAppliedBass = targetBassDb;
        futures.add(loudness.setTargetGain(targetBassDb).catchError((_) {}));
      }

      if (futures.isNotEmpty) {
        await Future.wait(futures);
      }

    } catch (e) {
      if (kDebugMode) print('EQ apply failed: $e');
    } finally {
      _isApplying = false;
      if (_pendingApply) {
        Future.delayed(const Duration(milliseconds: 50), _applyToAudioPlayer);
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}
