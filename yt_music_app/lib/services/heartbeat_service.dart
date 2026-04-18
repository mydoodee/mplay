import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class HeartbeatService {
  static final HeartbeatService _instance = HeartbeatService._internal();
  factory HeartbeatService() => _instance;
  HeartbeatService._internal();

  Timer? _timer;
  String? _deviceId;
  String? _deviceName;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString('device_id');
    
    if (_deviceId == null) {
      // Generate a simple unique ID since we don't have uuid package
      final random = Random().nextInt(1000000);
      _deviceId = 'dev_${DateTime.now().millisecondsSinceEpoch}_$random';
      await prefs.setString('device_id', _deviceId!);
    }

    _deviceName = _getDeviceName();

    // Send immediately on init
    _sendHeartbeat();

    // Send every 1 minute
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _sendHeartbeat();
    });
  }

  void dispose() {
    _timer?.cancel();
  }

  String _getDeviceName() {
    if (kIsWeb) return 'Web Browser';
    if (Platform.isAndroid) return 'Android Device';
    if (Platform.isIOS) return 'iOS Device';
    if (Platform.isWindows) return 'Windows Desktop';
    if (Platform.isMacOS) return 'Mac Desktop';
    if (Platform.isLinux) return 'Linux Desktop';
    return 'Unknown Device';
  }

  Future<void> _sendHeartbeat() async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/heartbeat'); // Using the base URL which is https://music.growkub.com/api
      // Wait, api endpoint in server is /api/heartbeat. So baseUrl is /api. We can just use '${ApiConfig.baseUrl}/heartbeat'
      // Wait, server.js defines app.post('/api/heartbeat'). If baseUrl is 'https://.../api', then `${ApiConfig.baseUrl}/heartbeat` becomes `.../api/heartbeat`. This is correct.
      
      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'deviceId': _deviceId,
          'deviceName': _deviceName,
          'platform': kIsWeb ? 'web' : Platform.operatingSystem,
        }),
      ).timeout(const Duration(seconds: 10));
      debugPrint('❤️ Heartbeat sent');
    } catch (e) {
      debugPrint('⚠️ Heartbeat failed: $e');
    }
  }
}
