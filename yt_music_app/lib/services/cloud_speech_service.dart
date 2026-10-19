import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../config/api_config.dart';

/// CloudSpeechService — บันทึกเสียงแล้วส่งไปแปลงเป็นข้อความผ่าน Backend API
/// ใช้เป็น Fallback บนอุปกรณ์ที่ไม่มี Google Speech Recognizer (เช่น จอรถยนต์ AOSP)
class CloudSpeechService {
  static AudioRecorder? _recorder;
  static String? _currentPath;
  static bool _isRecording = false;

  static bool get isRecording => _isRecording;

  /// เริ่มอัดเสียงจากไมค์
  static Future<bool> startRecording() async {
    try {
      _recorder ??= AudioRecorder();

      final hasPermission = await _recorder!.hasPermission();
      if (!hasPermission) {
        if (kDebugMode) print('🎙️ CloudSpeechService: No mic permission');
        return false;
      }

      final tempDir = await getTemporaryDirectory();
      _currentPath = '${tempDir.path}/speech_record.m4a';

      // ลบไฟล์เก่าถ้ามีอยู่
      final file = File(_currentPath!);
      if (await file.exists()) {
        await file.delete();
      }

      await _recorder!.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: _currentPath!,
      );

      _isRecording = true;
      if (kDebugMode) print('🎙️ CloudSpeechService: Recording started');
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ CloudSpeechService startRecording error: $e');
      _isRecording = false;
      return false;
    }
  }

  /// หยุดอัดเสียง แล้วส่งไฟล์ไปยัง Backend API เพื่อแปลงเป็นข้อความ
  /// คืนค่า String ข้อความที่แปลงได้ หรือ null ถ้าไม่พบเสียงพูด/เกิด error
  static Future<String?> stopAndRecognize({String locale = 'th-TH'}) async {
    if (!_isRecording || _recorder == null) return null;

    try {
      final path = await _recorder!.stop();
      _isRecording = false;

      if (path == null || !await File(path).exists()) {
        if (kDebugMode) print('❌ CloudSpeechService: Record file not found');
        return null;
      }

      final audioFile = File(path);
      final fileSize = await audioFile.length();
      if (fileSize < 1000) {
        // อัดเสียงสั้นเกินไปหรือไม่พบเสียง
        if (kDebugMode) print('⚠️ CloudSpeechService: File too small ($fileSize bytes)');
        return null;
      }

      final audioBytes = await audioFile.readAsBytes();
      final base64Audio = base64Encode(audioBytes);

      if (kDebugMode) {
        print('🎙️ CloudSpeechService: Sending audio ($fileSize bytes, base64 length: ${base64Audio.length}) to API...');
      }

      final response = await http
          .post(
            Uri.parse(ApiConfig.speechToTextUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'audio': base64Audio,
              'locale': locale,
              'format': 'm4a',
              'sampleRate': 16000,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final text = data['text'] as String?;
        if (kDebugMode) print('✅ CloudSpeechService STT result: "$text"');
        return text?.trim().isNotEmpty == true ? text!.trim() : null;
      } else {
        if (kDebugMode) {
          print('❌ CloudSpeechService API error: ${response.statusCode} - ${response.body}');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) print('❌ CloudSpeechService stopAndRecognize error: $e');
      _isRecording = false;
      return null;
    }
  }

  /// ยกเลิกการอัดเสียง
  static Future<void> cancel() async {
    try {
      if (_recorder != null && _isRecording) {
        await _recorder!.stop();
      }
    } catch (_) {}
    _isRecording = false;
  }
}
