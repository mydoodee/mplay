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
  String _selectedPreset = 'ปกติ';
  double _bassBoosterLevel = 0.0;
  List<double> _bandValues = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
  List<double> _customBandValues = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];

  final List<String> presets = ['ปกติ', 'ป๊อป', 'คลาสสิก', 'แจ๊ส', 'ร็อก', 'กำหนดเอง'];
  final List<String> bands = ['40', '150', '400', '1.2K', '3K', '5K', '12K'];

  bool get isEqualizerEnabled => _isEqualizerEnabled;
  String get selectedPreset => _selectedPreset;
  double get bassBoosterLevel => _bassBoosterLevel;
  List<double> get bandValues => _bandValues;

  EqualizerProvider(this.audioHandler) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isEqualizerEnabled = prefs.getBool('eq_enabled') ?? true;
    _selectedPreset = prefs.getString('eq_preset') ?? 'ปกติ';
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
      final loadedCustom = decodedCustom.map((e) => (e as num).toDouble()).toList();
      if (loadedCustom.length == 7) {
        _customBandValues = loadedCustom;
      }
    }
    
    notifyListeners();
    _applyToAudioPlayer();
  }

  Future<void> saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('eq_enabled', _isEqualizerEnabled);
    await prefs.setString('eq_preset', _selectedPreset);
    await prefs.setDouble('eq_bass_boost', _bassBoosterLevel);
    await prefs.setString('eq_bands', jsonEncode(_bandValues));
    await prefs.setString('eq_custom_bands', jsonEncode(_customBandValues));
    _applyToAudioPlayer();
  }

  void setEnabled(bool enabled) {
    _isEqualizerEnabled = enabled;
    notifyListeners();
    saveSettings();
  }

  void setPreset(String preset) {
    _selectedPreset = preset;
    if (_selectedPreset == 'ปกติ') {
      _bandValues = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
    } else if (preset == 'ป๊อป') {
      _bandValues = [-2.0, -1.0, 2.0, 3.0, 4.0, 2.0, -2.0];
    } else if (preset == 'ร็อก') {
      _bandValues = [5.0, 4.0, 2.0, -1.0, 2.0, 3.0, 5.0];
    } else if (preset == 'แจ๊ส') {
      _bandValues = [3.0, 2.0, 1.0, -1.0, 1.0, 2.0, 4.0];
    } else if (preset == 'คลาสสิก') {
      _bandValues = [4.0, 3.0, 2.0, -2.0, -1.0, 3.0, 4.0];
    } else if (preset == 'กำหนดเอง') {
      _bandValues = List.from(_customBandValues);
    }
    notifyListeners();
    saveSettings();
  }

  void setBandValue(int index, double value) {
    _bandValues[index] = value;
    _customBandValues[index] = value;
    _selectedPreset = 'กำหนดเอง';
    notifyListeners();
    saveSettings();
  }

  void setBassBoosterLevel(double value) {
    _bassBoosterLevel = value;
    notifyListeners();
    saveSettings();
  }

  Future<void> _applyToAudioPlayer() async {
    // Equalizer and LoudnessEnhancer are primarily Android features in just_audio
    if (!Platform.isAndroid) return;

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
          final bands = parameters.bands;
          for (int i = 0; i < min(bands.length, _bandValues.length); i++) {
            await bands[i].setGain(_bandValues[i] / 15.0);
          }
        } catch (e) {
          // This catches the "Map<dynamic, dynamic> is not a subtype of Map<String, dynamic>" 
          // or other platform-specific implementation errors
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
    }
  }
}
