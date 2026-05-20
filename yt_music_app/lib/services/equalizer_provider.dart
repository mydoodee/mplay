import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'audio_handler.dart';

class EqualizerProvider extends ChangeNotifier {
  final MyAudioHandler audioHandler;

  bool _isEqualizerEnabled = true;
  String _selectedPreset = 'normal';
  double _bassBoosterLevel = 0.0;
  List<double> _bandValues = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
  List<double> _customBandValues = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];

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

  // ── Mutex & Debounce Variables for Audio Thread Protection ──
  Timer? _applyTimer;
  bool _isApplying = false;
  bool _pendingApply = false;

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
        _bandValues = loaded;
      }
    }

    final savedCustom = prefs.getString('eq_custom_bands');
    if (savedCustom != null) {
      final List<dynamic> decodedCustom = jsonDecode(savedCustom);
      final loadedCustom = decodedCustom
          .map((e) => (e as num).toDouble())
          .toList();
      if (loadedCustom.length == 7) {
        _customBandValues = loadedCustom;
      }
    }

    notifyListeners();
    _applyToAudioPlayer();
  }

  Future<void> saveSettings({bool debounce = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('eq_enabled', _isEqualizerEnabled);
    await prefs.setString('eq_preset', _selectedPreset);
    await prefs.setDouble('eq_bass_boost', _bassBoosterLevel);
    await prefs.setString('eq_bands', jsonEncode(_bandValues));
    await prefs.setString('eq_custom_bands', jsonEncode(_customBandValues));
    
    if (debounce) {
      // Debounce continuous drag updates to prevent audio popping and flooding
      _applyTimer?.cancel();
      _applyTimer = Timer(const Duration(milliseconds: 100), () {
        _applyToAudioPlayer();
      });
    } else {
      _applyTimer?.cancel();
      _applyToAudioPlayer();
    }
  }

  void setEnabled(bool enabled) {
    _isEqualizerEnabled = enabled;
    notifyListeners();
    saveSettings(debounce: false);
  }

  void setPreset(String preset) {
    _selectedPreset = preset;
    if (_selectedPreset == 'normal') {
      _bandValues = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
    } else if (preset == 'pop') {
      // V-shaped curve (boosted low & high, dipped mid-range)
      _bandValues = [4.0, 2.5, -2.0, -3.5, -2.0, 3.0, 5.0];
    } else if (preset == 'rock') {
      // Bold aggressive rock curve
      _bandValues = [6.0, 4.5, -1.0, 1.5, 3.5, 5.0, 6.5];
    } else if (preset == 'jazz') {
      // Warm low end, smooth mids, gentle highs
      _bandValues = [5.0, 3.5, 2.0, -1.5, -1.0, 2.5, 4.0];
    } else if (preset == 'classic') {
      // Orchestral layout
      _bandValues = [5.0, 3.5, 1.5, -1.0, 2.0, 3.5, 4.5];
    } else if (preset == 'custom') {
      _bandValues = List.from(_customBandValues);
    }
    notifyListeners();
    saveSettings(debounce: false); // Presets are clicked, apply instantly
  }

  void setBandValue(int index, double value) {
    _bandValues[index] = value;
    _customBandValues[index] = value;
    _selectedPreset = 'custom';
    notifyListeners();
    saveSettings(debounce: true); // Sliders are dragged, use debounce
  }

  void setBassBoosterLevel(double value) {
    _bassBoosterLevel = value;
    notifyListeners();
    saveSettings(debounce: true); // Bass slider is dragged, use debounce
  }

  Future<void> _applyToAudioPlayer() async {
    // ── Mutex Lock Gatekeeper ──
    if (_isApplying) {
      _pendingApply = true;
      return;
    }
    _isApplying = true;
    _pendingApply = false;

    // Equalizer and LoudnessEnhancer are primarily Android features in just_audio
    if (!Platform.isAndroid) {
      _isApplying = false;
      return;
    }

    final eq = audioHandler.equalizer;
    final loudness = audioHandler.loudnessEnhancer;

    try {
      if (_isEqualizerEnabled) {
        await eq.setEnabled(true);

        // Bass Booster
        if (_bassBoosterLevel > 0) {
          try {
            await loudness.setEnabled(true);
            await loudness.setTargetGain(_bassBoosterLevel / 100.0);
          } catch (e) {
            debugPrint("LoudnessEnhancer error: $e");
          }
        } else {
          await loudness.setEnabled(false);
        }

        // Apply Equalizer
        try {
          final parameters = await eq.parameters;
          final bandsList = parameters.bands;
          
          // Apply gain to each band. Wrap in independent try-catches to prevent 
          // a single platform delay or channel issue from breaking the entire loop.
          for (int i = 0; i < min(bandsList.length, _bandValues.length); i++) {
            try {
              await bandsList[i].setGain(_bandValues[i]);
            } catch (bandError) {
              debugPrint("Error setting gain for band $i: $bandError");
            }
          }
        } catch (e) {
          debugPrint("Equalizer parameters error: $e");
        }
      } else {
        await eq.setEnabled(false);
        await loudness.setEnabled(false);
      }
    } catch (e) {
      if (kDebugMode) {
        print("Equalizer not supported or failed: $e");
      }
    } finally {
      _isApplying = false;
      // If another apply request was queued while processing, trigger it now
      if (_pendingApply) {
        _applyToAudioPlayer();
      }
    }
  }

  @override
  void dispose() {
    _applyTimer?.cancel();
    super.dispose();
  }
}
