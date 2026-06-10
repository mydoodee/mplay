import 'package:flutter/services.dart';

/// Service ที่เรียก Android Native RecognizerIntent
/// ใช้วิธีเดียวกับ YouTube — ส่ง Intent ให้ Android system จัดการทุกอย่าง
class NativeSpeechService {
  static const _channel = MethodChannel('com.ytmusic.yt_music_app/speech');

  /// เรียก Android native voice recognizer (RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
  /// 
  /// [locale] — ภาษาที่ต้องการ เช่น "th-TH", "en-US"
  /// [prompt] — ข้อความแสดงบน native UI (optional)
  /// 
  /// คืน String ที่รู้จำได้ หรือ null ถ้าผู้ใช้ยกเลิก/ไม่มีผลลัพธ์
  /// Throws PlatformException ถ้าไม่มี recognizer ติดตั้งอยู่
  static Future<String?> recognize({
    String locale = 'th-TH',
    String prompt = '',
  }) async {
    try {
      final result = await _channel.invokeMethod<String>(
        'startVoiceRecognition',
        {
          'locale': locale,
          'prompt': prompt,
        },
      );
      return result;
    } on PlatformException catch (e) {
      if (e.code == 'NO_RECOGNIZER') {
        // ไม่พบ speech recognizer บนอุปกรณ์นี้
        rethrow;
      }
      // Error อื่น ๆ
      rethrow;
    }
  }
}
