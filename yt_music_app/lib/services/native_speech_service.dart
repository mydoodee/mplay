import 'dart:async';
import 'package:flutter/services.dart';

/// Service ที่เรียก Android SpeechRecognizer API โดยตรง (in-process)
/// ทำงานได้บนจอรถยนต์ที่ไม่มี Google app ตราบใดที่มี speech recognizer service ใดๆ
///
/// ปรับปรุง: เพิ่ม timeout safeguard ฝั่ง Dart
/// กรณี native side ค้าง (ไม่ส่ง result กลับ) จะ timeout ใน 30 วินาที
class NativeSpeechService {
  static const _channel = MethodChannel('com.ytmusic.yt_music_app/speech');
  static const _eventChannel = EventChannel(
    'com.ytmusic.yt_music_app/speech_events',
  );

  /// Cached broadcast stream — ป้องกันไม่ให้เรียก receiveBroadcastStream() ซ้ำ
  /// ซึ่งจะทำให้ EventSink ฝั่ง native ถูกแทนที่ และ event หลุด
  static Stream<Map<String, dynamic>>? _cachedEventStream;

  /// เช็คว่ามี speech recognizer พร้อมใช้งานบนอุปกรณ์นี้หรือไม่
  static Future<bool> isAvailable() async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'checkRecognizerAvailable',
      );
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// เตรียม EventChannel ให้พร้อมรับ events ก่อนเริ่ม recognition
  /// ต้องเรียกก่อน recognize() เพื่อให้ eventSink ฝั่ง native ถูกตั้งค่า
  static Future<void> ensureEventChannelReady() async {
    if (_cachedEventStream == null) {
      // สร้าง broadcast stream จาก EventChannel เพียงครั้งเดียว
      _cachedEventStream = _eventChannel.receiveBroadcastStream().map((event) {
        if (event is Map) {
          return Map<String, dynamic>.from(event);
        }
        return <String, dynamic>{'event': 'unknown'};
      }).asBroadcastStream();

      // รอ 1 frame ให้ native side ตั้งค่า eventSink เสร็จ
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  /// เรียก Android SpeechRecognizer (in-process, ไม่ต้องเปิด Activity ภายนอก)
  ///
  /// [locale] — ภาษาที่ต้องการ เช่น "th-TH", "en-US"
  ///
  /// คืน String ที่รู้จำได้ หรือ null ถ้าผู้ใช้ยกเลิก/ไม่มีผลลัพธ์
  /// Throws PlatformException ถ้าไม่มี recognizer ติดตั้งอยู่
  ///
  /// มี timeout 30 วินาที — ถ้า native side ค้างไม่ส่งผลลัพธ์กลับ
  /// จะ return null แทนที่จะค้างตลอด
  static Future<String?> recognize({String locale = 'th-TH'}) async {
    // ตรวจสอบว่า EventChannel พร้อมรับ events แล้ว
    await ensureEventChannelReady();

    try {
      final result = await _channel.invokeMethod<String>(
        'startVoiceRecognition',
        {'locale': locale},
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          // Native side ค้าง → หยุด recognizer แล้ว return null
          stop();
          return null;
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
    _cachedEventStream ??= _eventChannel.receiveBroadcastStream().map((event) {
      if (event is Map) {
        return Map<String, dynamic>.from(event);
      }
      return <String, dynamic>{'event': 'unknown'};
    }).asBroadcastStream();
    return _cachedEventStream!;
  }
}
