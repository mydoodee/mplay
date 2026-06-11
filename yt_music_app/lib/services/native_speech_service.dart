import 'package:flutter/services.dart';

/// Service ที่เรียก Android SpeechRecognizer API โดยตรง (in-process)
/// ทำงานได้บนจอรถยนต์ที่ไม่มี Google app ตราบใดที่มี speech recognizer service ใดๆ
class NativeSpeechService {
  static const _channel = MethodChannel('com.ytmusic.yt_music_app/speech');
  static const _eventChannel =
      EventChannel('com.ytmusic.yt_music_app/speech_events');

  /// เช็คว่ามี speech recognizer พร้อมใช้งานบนอุปกรณ์นี้หรือไม่
  static Future<bool> isAvailable() async {
    try {
      final result = await _channel.invokeMethod<bool>('checkRecognizerAvailable');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// เรียก Android SpeechRecognizer (in-process, ไม่ต้องเปิด Activity ภายนอก)
  ///
  /// [locale] — ภาษาที่ต้องการ เช่น "th-TH", "en-US"
  ///
  /// คืน String ที่รู้จำได้ หรือ null ถ้าผู้ใช้ยกเลิก/ไม่มีผลลัพธ์
  /// Throws PlatformException ถ้าไม่มี recognizer ติดตั้งอยู่
  static Future<String?> recognize({
    String locale = 'th-TH',
  }) async {
    try {
      final result = await _channel.invokeMethod<String>(
        'startVoiceRecognition',
        {'locale': locale},
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

  /// หยุดการฟัง
  static Future<void> stop() async {
    try {
      await _channel.invokeMethod('stopVoiceRecognition');
    } on PlatformException {
      // ignore
    }
  }

  /// Stream ของ speech events (partial results, rms, etc.)
  /// Events เป็น Map<String, dynamic> ที่มี key "event" เป็น:
  /// - "ready": พร้อมรับเสียง
  /// - "speechStart": เริ่มตรวจจับเสียงพูด
  /// - "speechEnd": เสียงพูดจบ
  /// - "partialResult": ผลลัพธ์บางส่วน (มี "text")
  /// - "finalResult": ผลลัพธ์สุดท้าย (มี "text")
  /// - "rms": ระดับเสียง (มี "value")
  /// - "error": เกิดข้อผิดพลาด (มี "code")
  static Stream<Map<String, dynamic>> get events {
    return _eventChannel.receiveBroadcastStream().map((event) {
      if (event is Map) {
        return Map<String, dynamic>.from(event);
      }
      return <String, dynamic>{'event': 'unknown'};
    });
  }
}
