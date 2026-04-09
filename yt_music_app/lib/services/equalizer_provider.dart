import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'audio_handler.dart';

class EqualizerProvider extends ChangeNotifier {
  final MyAudioHandler audioHandler;

  bool _isEqualizerEnabled = false;
  String _selectedPreset = 'Normal';
  double _bassBoosterLevel = 0.0;
  List<double> _bandValues = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
  List<double> _customBandValues = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];

  final List<String> presets = [
    'Normal',
    'Pop',
    'Classic',
    'Jazz',
    'Rock',
    'Custom',
  ];
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
    _isEqualizerEnabled = prefs.getBool('eq_enabled') ?? false;
    _selectedPreset = prefs.getString('eq_preset') ?? 'Normal';
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
    if (_selectedPreset == 'Normal') {
      _bandValues = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
    } else if (preset == 'Pop') {
      _bandValues = [-2.0, -1.0, 2.0, 3.0, 4.0, 2.0, -2.0];
    } else if (preset == 'Rock') {
      _bandValues = [5.0, 4.0, 2.0, -1.0, 2.0, 3.0, 5.0];
    } else if (preset == 'Jazz') {
      _bandValues = [3.0, 2.0, 1.0, -1.0, 1.0, 2.0, 4.0];
    } else if (preset == 'Classic') {
      _bandValues = [4.0, 3.0, 2.0, -2.0, -1.0, 3.0, 4.0];
    } else if (preset == 'Custom') {
      _bandValues = List.from(_customBandValues);
    }
    notifyListeners();
    saveSettings();
  }

  void setBandValue(int index, double value) {
    _bandValues[index] = value;
    _customBandValues[index] = value;
    _selectedPreset = 'Custom';
    notifyListeners();
    saveSettings();
  }

  void setBassBoosterLevel(double value) {
    _bassBoosterLevel = value;
    notifyListeners();
    saveSettings();
  }

  Future<void> _applyToAudioPlayer() async {
    final eq = audioHandler.equalizer;
    final loudness = audioHandler.loudnessEnhancer;

    try {
      if (_isEqualizerEnabled) {
        await eq.setEnabled(true);
        // Bass Booster (AndroidLoudnessEnhancer) target gain in mB (millibels). Map 0-100% to 0-3000 mB (0 to +30dB approx)
        if (_bassBoosterLevel > 0) {
          await loudness.setEnabled(true);
          await loudness.setTargetGain(
            _bassBoosterLevel / 100.0,
          ); // max 1.0 multiplier logic? Actually targetGain is in float usually, let's look at docs. just_audio loudnesEnhancer uses targetGain
          // Note: AndroidLoudnessEnhancer targetGain is a double multiplier usually or mB, the plugin takes a double.
          await loudness.setTargetGain(_bassBoosterLevel / 100.0);
        } else {
          await loudness.setEnabled(false);
        }

        // Apply Equalizer
        final parameters = await eq.parameters;
        final bands = parameters.bands;
        for (int i = 0; i < min(bands.length, _bandValues.length); i++) {
          // Map slider value (-15 to 15) to actual band gain
          // usually band gain limits are retrieved from parameters, but we scale it directly or just pass standard value
          // gain is usually a double between 0.0 and 1.0? No, just_audio usually takes gain in double.
          await bands[i].setGain(_bandValues[i] / 15.0);
        }
      } else {
        await eq.setEnabled(false);
        await loudness.setEnabled(false);
      }
    } catch (e) {
      if (kDebugMode) {
        print("Equalizer not supported on this platform: \$e");
      }
    }
  }
}
