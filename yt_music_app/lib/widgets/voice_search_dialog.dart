import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/native_speech_service.dart';

class VoiceSearchDialog extends StatefulWidget {
  final String initialLocale;
  const VoiceSearchDialog({super.key, required this.initialLocale});

  @override
  State<VoiceSearchDialog> createState() => _VoiceSearchDialogState();
}

class _VoiceSearchDialogState extends State<VoiceSearchDialog> {
  bool _isListening = false;
  String _recognizedWords = '';
  String _partialWords = '';
  String _errorMessage = '';
  bool _showTextInput = false; // true = แสดงช่องพิมพ์ค้นหาแทน
  bool _activityLaunched = false; // true = Google Speech Dialog กำลังเปิดอยู่

  StreamSubscription? _eventSub;
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    _initAndStart();
  }

  Future<void> _initAndStart() async {
    // ขอ permission ไมค์ก่อน
    // บนอุปกรณ์รถยนต์ (head unit) permission อาจถูก grant ไว้แล้วโดยระบบ
    // หรือไม่รองรับ runtime permission dialog — จึงต้อง handle ทั้งสองกรณี
    try {
      var status = await Permission.microphone.status;
      if (!status.isGranted) {
        status = await Permission.microphone.request();
        if (!status.isGranted) {
          // บน head unit บางรุ่น status อาจ report ผิด
          // ลองเริ่มฟังเลยถ้า permission request ล้มเหลว
          // SpeechRecognizer จะ report PERMISSION_ERROR เองถ้าไม่มี permission จริง
          _startListening();
          return;
        }
      }
    } catch (e) {
      // permission_handler อาจ throw บน head unit บางรุ่น → ข้ามไปลองฟังเลย
    }

    _startListening();
  }

  void _startListening() {
    setState(() {
      _isListening = true;
      _recognizedWords = '';
      _partialWords = '';
      _errorMessage = '';
      _activityLaunched = false;
    });

    // Subscribe to speech events ก่อน
    _eventSub?.cancel();
    _eventSub = NativeSpeechService.events.listen((event) {
      if (!mounted) return;
      final eventType = event['event'] as String?;

      switch (eventType) {
        case 'partialResult':
          setState(() {
            _partialWords = event['text'] as String? ?? '';
          });
          break;
        case 'finalResult':
          final text = event['text'] as String? ?? '';
          if (text.isNotEmpty) {
            setState(() {
              _recognizedWords = text;
            });
          }
          break;
        case 'rms':
          // ไม่ใช้ rmsLevel แล้ว (เอา animation สั่นออก)
          break;
        case 'activityLaunched':
          // Google Speech Dialog เปิดขึ้นแล้ว (Activity-based, แบบ YouTube)
          // ซ่อน error เดิมและแสดงสถานะ
          setState(() {
            _activityLaunched = true;
            _isListening = true;
            _errorMessage = '';
          });
          break;
        case 'error':
          final code = event['code'] as String? ?? '';
          // ถ้าเป็น WATCHDOG_TIMEOUT ไม่ต้องแสดง error ทันที
          // เพราะ native กำลัง fallback ไป recognizer อื่นอัตโนมัติ
          if (code == 'WATCHDOG_TIMEOUT') {
            // ไม่ต้องทำอะไร — native จะ fallback เอง
            break;
          }
          setState(() {
            _isListening = false;
            _errorMessage = _getFriendlyError(code);
          });
          break;
        case 'speechEnd':
          setState(() => _isListening = false);
          break;
      }
    });

    // เริ่ม recognize (ensureEventChannelReady จะถูกเรียกภายใน recognize อัตโนมัติ)
    NativeSpeechService.recognize(locale: widget.initialLocale)
        .then((result) {
          if (!mounted) return;
          if (result != null && result.isNotEmpty) {
            // สำเร็จ! ส่งผลลัพธ์กลับไป ค้นหาทันที
            Navigator.pop(context, result);
          } else {
            // ไม่มีผลลัพธ์ แต่ไม่มี error รุนแรง (เช่น ผู้ใช้อาจจะกดยกเลิกเอง)
            setState(() {
              _isListening = false;
            });
          }
        })
        .catchError((e) {
          if (!mounted) return;
          String errStr = e.toString();
          if (e is PlatformException) {
            errStr = e.code;
            if (e.message != null && e.message!.isNotEmpty) {
              errStr = '${e.code}: ${e.message}';
            }
          }
          setState(() {
            _isListening = false;
            _errorMessage = _getFriendlyError(errStr);
          });
        });
  }

  String _getFriendlyError(String code) {
    if (code.contains('NO_RECOGNIZER')) {
      return widget.initialLocale.startsWith('th')
          ? 'อุปกรณ์นี้ไม่มีระบบค้นหาด้วยเสียง กรุณาพิมพ์ค้นหาแทน'
          : 'Voice search is not available on this device. Please type to search.';
    }
    if (code.contains('PERMISSION_ERROR') ||
        code.contains('INSUFFICIENT_PERMISSIONS')) {
      return widget.initialLocale.startsWith('th')
          ? 'กรุณาอนุญาตสิทธิ์การเข้าถึงไมโครโฟนในการตั้งค่าระบบ'
          : 'Please grant microphone access in system settings.';
    }
    if (code.contains('NETWORK_ERROR') ||
        code.contains('NETWORK_TIMEOUT') ||
        code.contains('SERVER_ERROR')) {
      return widget.initialLocale.startsWith('th')
          ? 'การเชื่อมต่อเครือข่ายขัดข้อง กรุณาตรวจสอบอินเทอร์เน็ต'
          : 'Network connection error. Please check your internet connection.';
    }
    if (code.contains('AUDIO_ERROR')) {
      return widget.initialLocale.startsWith('th')
          ? 'ระบบบันทึกเสียงขัดข้อง กรุณาลองใหม่อีกครั้ง'
          : 'Microphone recording error. Please try again.';
    }
    if (code.contains('CLIENT_ERROR')) {
      return widget.initialLocale.startsWith('th')
          ? 'บริการค้นหาด้วยเสียงของระบบขัดข้อง กรุณาพิมพ์ค้นหาแทน'
          : 'System voice search service error. Please type to search.';
    }
    if (code.contains('RECOGNIZER_BUSY')) {
      return widget.initialLocale.startsWith('th')
          ? 'ระบบค้นหาด้วยเสียงกำลังทำงานอื่นอยู่ กรุณาลองใหม่'
          : 'Voice recognition is busy. Please try again.';
    }
    if (code.contains('NO_MATCH') || code.contains('SPEECH_TIMEOUT')) {
      return widget.initialLocale.startsWith('th')
          ? 'ตรวจไม่พบเสียงพูดของคุณ กรุณาลองใหม่อีกครั้ง'
          : 'No speech recognized. Please try again.';
    }
    if (code.contains('WATCHDOG_TIMEOUT')) {
      return widget.initialLocale.startsWith('th')
          ? 'ระบบค้นหาด้วยเสียงไม่ตอบสนอง กรุณาลองใหม่หรือพิมพ์ค้นหาแทน'
          : 'Voice search is not responding. Please try again or type to search.';
    }
    if (code.contains('LANGUAGE_UNAVAILABLE') || code.contains('LANGUAGE_NOT_SUPPORTED')) {
      return widget.initialLocale.startsWith('th')
          ? 'อุปกรณ์นี้ไม่รองรับระบบสั่งงานด้วยเสียงในภาษาของคุณ กรุณาพิมพ์ค้นหาแทน'
          : 'Search language is not supported on this device. Please type to search.';
    }
    if (code.contains('NO_SPEECH_ACTIVITY')) {
      return widget.initialLocale.startsWith('th')
          ? 'ไม่พบระบบค้นหาด้วยเสียงบนอุปกรณ์นี้ กรุณาพิมพ์ค้นหาแทน'
          : 'No voice search service found on this device. Please type to search.';
    }
    if (code.contains('UNKNOWN_ERROR')) {
      return widget.initialLocale.startsWith('th')
          ? 'อุปกรณ์นี้ไม่รองรับบริการค้นหาด้วยเสียง หรือระบบบริการขัดข้อง'
          : 'Voice search is not supported on this device, or service is unavailable.';
    }
    return widget.initialLocale.startsWith('th')
        ? 'ไม่สามารถใช้การค้นหาด้วยเสียงได้ ($code)'
        : 'Voice search failed ($code)';
  }

  void _retryListening() {
    setState(() {
      _showTextInput = false;
      _errorMessage = '';
    });
    _startListening();
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _textController.dispose();
    _textFocusNode.dispose();
    NativeSpeechService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayText = _recognizedWords.isNotEmpty
        ? _recognizedWords
        : (_partialWords.isNotEmpty ? _partialWords : '');

    return Scaffold(
      backgroundColor: const Color(
        0xFFE5DCE3,
      ), // สีชมพูอมม่วงสว่าง เลียนแบบ YouTube ในรูป
      body: SafeArea(
        child: Column(
          children: [
            // ── Header Row ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // ปุ่มปิด (X)
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF505050),
                      size: 28,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),

                  // Pill toggle เสียง / เพลง เลียนแบบ YouTube
                  if (!_showTextInput)
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCD2DA),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFD0C4CE)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.mic_rounded,
                                  color: Color(0xFFE52116),
                                  size: 16,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'เสียง',
                                  style: TextStyle(
                                    color: Color(0xFF202020),
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    widget.initialLocale.startsWith('th')
                                        ? 'ระบบค้นหาด้วยทำนองเพลงจะพร้อมใช้งานในเวอร์ชันถัดไป'
                                        : 'Hum-to-search feature will be available in the next version.',
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              color: Colors.transparent,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.music_note_rounded,
                                    color: const Color(0xFF707070),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'เพลง',
                                    style: TextStyle(
                                      color: const Color(0xFF707070),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    const SizedBox(width: 100), // จัดความสมดุลหน้าจอ
                  // ปุ่มขวา: ปุ่มตั้งค่า หรือ ปุ่มไมค์ (เพื่อสลับกลับมาโหมดเสียงเมื่ออยู่ในโหมดคีย์บอร์ด)
                  if (_showTextInput)
                    IconButton(
                      icon: const Icon(
                        Icons.mic_rounded,
                        color: Color(0xFF505050),
                        size: 26,
                      ),
                      onPressed: () {
                        _retryListening();
                      },
                    )
                  else
                    IconButton(
                      icon: const Icon(
                        Icons.settings_outlined,
                        color: Color(0xFF505050),
                        size: 24,
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              widget.initialLocale.startsWith('th')
                                  ? 'การตั้งค่าระบบค้นหาด้วยเสียง'
                                  : 'Voice search settings',
                            ),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            const Spacer(),

            // ── Content area ──
            if (_showTextInput) ...[
              // ── โหมดพิมพ์ค้นหา (ปรับปรุงให้เป็นธีมสว่างพรีเมียมเข้ากัน) ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    const Icon(
                      Icons.keyboard_rounded,
                      color: Color(0xFF606060),
                      size: 40,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.initialLocale.startsWith('th')
                          ? 'พิมพ์เพื่อค้นหาเพลง'
                          : 'Type to search songs',
                      style: const TextStyle(
                        color: Color(0xFF606060),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: Border.all(
                          color: const Color(0xFFE52116).withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: TextField(
                        controller: _textController,
                        focusNode: _textFocusNode,
                        textInputAction: TextInputAction.search,
                        style: const TextStyle(
                          color: Color(0xFF202020),
                          fontSize: 18,
                        ),
                        decoration: InputDecoration(
                          hintText: widget.initialLocale.startsWith('th')
                              ? 'พิมพ์ชื่อเพลง...'
                              : 'Type song name...',
                          hintStyle: const TextStyle(
                            color: Color(0xFF909090),
                            fontSize: 16,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          border: InputBorder.none,
                          suffixIcon: IconButton(
                            icon: const Icon(
                              Icons.search_rounded,
                              color: Color(0xFFE52116),
                              size: 26,
                            ),
                            onPressed: () {
                              final text = _textController.text.trim();
                              if (text.isNotEmpty) {
                                Navigator.pop(context, text);
                              }
                            },
                          ),
                        ),
                        onSubmitted: (text) {
                          final trimmed = text.trim();
                          if (trimmed.isNotEmpty) {
                            Navigator.pop(context, trimmed);
                          }
                        },
                      ),
                    ),
                    if (_errorMessage.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFD32F2F),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ] else ...[
              // ── โหมดฟังเสียง เลียนแบบ YouTube ──
              Padding(
                padding: const EdgeInsets.only(left: 48, right: 48, bottom: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isListening
                            ? (_activityLaunched
                                  ? (widget.initialLocale.startsWith('th')
                                        ? 'กำลังเริ่มการค้นหาด้วยเสียง...'
                                        : 'Starting voice search...')
                                  : (widget.initialLocale.startsWith('th')
                                        ? 'กำลังฟัง...'
                                        : 'Listening...'))
                            : (_errorMessage.isNotEmpty
                                  ? (widget.initialLocale.startsWith('th')
                                        ? 'เกิดข้อผิดพลาด'
                                        : 'Voice Search Error')
                                  : (widget.initialLocale.startsWith('th')
                                        ? 'แตะเพื่อพูด'
                                        : 'Tap to speak')),
                        style: TextStyle(
                          color: _errorMessage.isNotEmpty
                              ? const Color(0xFFD32F2F)
                              : const Color(0xFF1F1F1F),
                          fontSize: 34,
                          fontWeight: FontWeight.w400,
                          letterSpacing: -0.5,
                        ),
                      ),
                      if (displayText.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          displayText,
                          style: const TextStyle(
                            color: Color(0xFF1F1F1F),
                            fontSize: 24,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ] else if (_errorMessage.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage,
                          style: const TextStyle(
                            color: Color(0xFF606060),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // ปุ่มไมค์สีแดง — ไม่มี animation สั่น, ใช้ AnimatedOpacity แทน
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // วงรอบนอก — แสดงเฉพาะตอนฟัง, ใช้ AnimatedOpacity แทน pulse
                    AnimatedOpacity(
                      opacity: _isListening ? 0.12 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: Container(
                        width: 130,
                        height: 130,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFE52116),
                        ),
                      ),
                    ),
                    // วงรอบใน — แสดงเฉพาะตอนฟัง
                    AnimatedOpacity(
                      opacity: _isListening ? 0.2 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFE52116),
                        ),
                      ),
                    ),
                    // พื้นหลังสีขาว
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    // ปุ่มไมโครโฟนสีแดง (YouTube Style) — ไม่มี animation สั่น
                    GestureDetector(
                      onTap: () {
                        if (_isListening) {
                          NativeSpeechService.stop();
                          setState(() => _isListening = false);
                        } else {
                          _startListening();
                        }
                      },
                      child: Container(
                        width: 82,
                        height: 82,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFE52116),
                        ),
                        child: const Icon(
                          Icons.mic_rounded,
                          color: Colors.white,
                          size: 44,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ปุ่มคีย์บอร์ดด้านล่าง เพื่อให้สลับไปพิมพ์ได้
              IconButton(
                icon: const Icon(
                  Icons.keyboard_rounded,
                  color: Color(0xFF606060),
                  size: 30,
                ),
                onPressed: () {
                  setState(() => _showTextInput = true);
                  Future.delayed(const Duration(milliseconds: 300), () {
                    if (mounted) _textFocusNode.requestFocus();
                  });
                },
              ),
              const SizedBox(height: 8),

              Text(
                _isListening
                    ? (widget.initialLocale.startsWith('th')
                          ? 'แตะไมค์เพื่อหยุด'
                          : 'Tap mic to stop')
                    : (widget.initialLocale.startsWith('th')
                          ? 'แตะไมค์เพื่อพูดอีกครั้ง'
                          : 'Tap mic to speak again'),
                style: const TextStyle(color: Color(0xFF707070), fontSize: 13),
              ),
            ],
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }
}
