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

  // ── Soft Ramp Engine state ──
  List<double> _currentAppliedGains = [0.0, 0.0, 0.0, 0.0, 0.0]; // hw bands
  double _currentAppliedBass = 0.0;
  Timer? _rampTimer;

  // ── Throttle for drag ──
  DateTime _lastApplyTime = DateTime(2000);
  Timer? _throttleTimer;
  static const _throttleMs = 200;

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
        _bandValues = loaded.map((v) => v.clamp(-12.0, 12.0)).toList();
      }
    }

    final savedCustom = prefs.getString('eq_custom_bands');
    if (savedCustom != null) {
      final List<dynamic> decodedCustom = jsonDecode(savedCustom);
      final loadedCustom = decodedCustom.map((e) => (e as num).toDouble()).toList();
      if (loadedCustom.length == 7) {
        _customBandValues = loadedCustom.map((v) => v.clamp(-12.0, 12.0)).toList();
      }
    }

    if (_selectedPreset != 'custom') {
      _bandValues = _getPresetValues(_selectedPreset);
    }

    notifyListeners();
    // On load: apply directly without ramp (no audio playing yet)
    _applyToAudioPlayer(skipRamp: true);
  }

  List<double> _getPresetValues(String preset) {
    switch (preset) {
      case 'pop':     return [2.5,  1.5, -1.0, -1.5, -0.5,  2.0, 3.0];
      case 'rock':    return [4.0,  3.0, -0.5,  0.5,  2.0,  3.5, 4.0];
      case 'jazz':    return [3.5,  2.5,  1.0, -0.5, -0.5,  1.5, 2.5];
      case 'classic': return [3.0,  2.0,  0.5, -0.5,  1.0,  2.0, 3.0];
      case 'normal':
      default:        return [0.0,  0.0,  0.0,  0.0,  0.0,  0.0, 0.0];
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

  Future<void> _saveAndApply() async {
    await _saveSettings();
    _applyToAudioPlayer();
  }

  // ── Throttle during dragging ──
  void _throttledApply() {
    final now = DateTime.now();
    final elapsed = now.difference(_lastApplyTime).inMilliseconds;
    if (elapsed >= _throttleMs) {
      _lastApplyTime = now;
      _throttleTimer?.cancel();
      _applyToAudioPlayer();
    } else {
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
    _throttledApply();
  }

  void commitBandValue(int index, double value) {
    _bandValues[index] = value;
    _customBandValues[index] = value;
    _selectedPreset = 'custom';
    _throttleTimer?.cancel();
    notifyListeners();
    _saveAndApply();
  }

  void setBassBoosterVisual(double value) {
    _bassBoosterLevel = value;
    notifyListeners();
    _throttledApply();
  }

  void commitBassBooster(double value) {
    _bassBoosterLevel = value;
    _throttleTimer?.cancel();
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

    // Generic interpolation
    final result = <double>[];
    for (int i = 0; i < _hwBandCount; i++) {
      final ratio = i / (_hwBandCount - 1) * (uiBands.length - 1);
      final low = ratio.floor();
      final high = ratio.ceil().clamp(0, uiBands.length - 1);
      result.add(uiBands[low] * (1 - (ratio - low)) + uiBands[high] * (ratio - low));
    }
    return result;
  }

  double _safeGain(double gain) => gain.clamp(_hwMinGain, _hwMaxGain);

  List<double> _antiClip(List<double> gains) {
    double maxBoost = gains.fold(0.0, (m, g) => g > m ? g : m);
    if (maxBoost <= 8.0) return gains;
    final scale = 8.0 / maxBoost;
    return gains.map((g) => g * scale).toList();
  }

  // ════════════════════════════════════════════
  // SOFT RAMP ENGINE v2
  // ════════════════════════════════════════════
  //
  // ปัญหา v1: cancel + restart timer ทุกครั้ง → gap → เสียงแทก
  //
  // แก้ v2: เก็บ target เป็น instance variable
  //          timer วิ่งต่อเนื่อง ไม่เคย cancel/restart
  //          แค่อัปเดต target → timer อ่านค่าใหม่เอง
  //          = ไม่มี gap = ไม่มีเสียงแทก

  // Target values (updated instantly when user drags)
  List<double> _targetBandGains = [];
  double _targetBassGain = 0.0;

  // Cached references for the ramp timer to use
  AndroidEqualizerParameters? _rampParameters;
  AndroidLoudnessEnhancer? _rampLoudness;

  // Ramp timer state
  bool _rampRunning = false;
  static const _rampIntervalMs = 20;  // 50fps — smooth enough, not too CPU heavy
  static const _rampStepDb = 0.3;     // smaller step = smoother = no click

  void _updateRampTargets({
    required List<double> targetBandGains,
    required double targetBassGain,
    required AndroidEqualizerParameters parameters,
    required AndroidLoudnessEnhancer loudness,
  }) {
    // Update targets (timer will pick them up on next tick)
    _targetBandGains = List.from(targetBandGains);
    _targetBassGain = targetBassGain;
    _rampParameters = parameters;
    _rampLoudness = loudness;

    // Ensure _currentAppliedGains matches hw band count
    while (_currentAppliedGains.length < targetBandGains.length) {
      _currentAppliedGains.add(0.0);
    }
    if (_currentAppliedGains.length > targetBandGains.length) {
      _currentAppliedGains = _currentAppliedGains
          .take(targetBandGains.length).toList();
    }

    // Start ramp timer if not already running
    if (!_rampRunning) {
      _rampRunning = true;
      _rampTick(); // start first tick immediately
    }
  }

  Future<void> _rampTick() async {
    if (!_rampRunning) return;
    final params = _rampParameters;
    final loud = _rampLoudness;
    if (params == null || loud == null) {
      _rampRunning = false;
      return;
    }

    bool allDone = true;
    final futures = <Future>[];

    // ── Step each EQ band toward target ──
    for (int i = 0; i < min(params.bands.length, _targetBandGains.length); i++) {
      final current = _currentAppliedGains[i];
      final target = _targetBandGains[i];
      final diff = target - current;

      double next;
      if (diff.abs() <= _rampStepDb) {
        next = target;
      } else {
        next = current + (diff > 0 ? _rampStepDb : -_rampStepDb);
        allDone = false;
      }
      if (next != current) {
        _currentAppliedGains[i] = next;
        futures.add(
          params.bands[i].setGain(_safeGain(next)).catchError((_) {}),
        );
      }
    }

    // ── Step bass toward target ──
    final bassDiff = _targetBassGain - _currentAppliedBass;
    if (bassDiff.abs() > 0.01) {
      double nextBass;
      if (bassDiff.abs() <= _rampStepDb) {
        nextBass = _targetBassGain;
      } else {
        nextBass = _currentAppliedBass +
            (bassDiff > 0 ? _rampStepDb : -_rampStepDb);
        allDone = false;
      }
      _currentAppliedBass = nextBass;
      futures.add(loud.setTargetGain(nextBass).catchError((_) {}));
    }

    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }

    if (allDone) {
      // Check one more time (target may have been updated during await)
      bool stillDone = true;
      for (int i = 0; i < _targetBandGains.length; i++) {
        if (i < _currentAppliedGains.length &&
            (_targetBandGains[i] - _currentAppliedGains[i]).abs() > 0.01) {
          stillDone = false;
          break;
        }
      }
      if ((_targetBassGain - _currentAppliedBass).abs() > 0.01) {
        stillDone = false;
      }

      if (stillDone) {
        _rampRunning = false;
        _rampTimer?.cancel();
        _rampTimer = null;
        return;
      }
    }

    // Schedule next tick (non-periodic to avoid overlap with slow await)
    _rampTimer?.cancel();
    _rampTimer = Timer(const Duration(milliseconds: _rampIntervalMs), _rampTick);
  }

  // ════════════════════════════════════════════

  Future<void> _applyToAudioPlayer({bool skipRamp = false}) async {
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
      // Init once
      if (!_effectsInitialized) {
        try {
          await eq.setEnabled(true);
          await loudness.setEnabled(true);
          _effectsInitialized = true;
        } catch (_) {}
      }

      // Query & cache hardware range once
      if (!_hwRangeQueried) {
        try {
          _cachedParameters = await eq.parameters;
          _hwMinGain = _cachedParameters!.minDecibels;
          _hwMaxGain = _cachedParameters!.maxDecibels;
          _hwBandCount = _cachedParameters!.bands.length;
          _hwRangeQueried = true;
          // Initialize current gains array to match hw band count
          _currentAppliedGains = List.filled(_hwBandCount, 0.0);
          debugPrint('🎛️ EQ HW: bands=$_hwBandCount, '
              'range=[$_hwMinGain, $_hwMaxGain] dB');
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

      if (skipRamp) {
        // Apply directly (no ramp) — used on initial load when no audio
        _rampRunning = false;
        _rampTimer?.cancel();
        _rampTimer = null;
        final futures = <Future>[];
        for (int i = 0; i < min(parameters.bands.length, targetHwGains.length); i++) {
          if (i < _currentAppliedGains.length) {
            _currentAppliedGains[i] = targetHwGains[i];
          }
          futures.add(parameters.bands[i].setGain(targetHwGains[i]).catchError((_) {}));
        }
        _currentAppliedBass = targetBassDb;
        futures.add(loudness.setTargetGain(targetBassDb).catchError((_) {}));
        await Future.wait(futures);
      } else {
        // Soft ramp v2 — just update targets, timer continues smoothly
        _updateRampTargets(
          targetBandGains: targetHwGains,
          targetBassGain: targetBassDb,
          parameters: parameters,
          loudness: loudness,
        );
      }
    } catch (e) {
      if (kDebugMode) print('EQ apply failed: $e');
    } finally {
      _isApplying = false;
      if (_pendingApply) {
        Future.delayed(const Duration(milliseconds: 80), _applyToAudioPlayer);
      }
    }
  }

  @override
  void dispose() {
    _rampTimer?.cancel();
    _throttleTimer?.cancel();
    super.dispose();
  }
}
