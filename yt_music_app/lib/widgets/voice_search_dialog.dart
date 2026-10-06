import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/native_speech_service.dart';

/// Voice Search Dialog — ใช้ Android Activity-based Speech Recognition
/// เหมือน YouTube ค้นหาด้วยเสียง (ไม่ผ่าน Cloud STT)
class VoiceSearchDialog extends StatefulWidget {
  final String initialLocale;
  const VoiceSearchDialog({super.key, required this.initialLocale});

  @override
  State<VoiceSearchDialog> createState() => _VoiceSearchDialogState();
}

class _VoiceSearchDialogState extends State<VoiceSearchDialog>
    with SingleTickerProviderStateMixin {
  bool _isListening = false;
  String _recognizedWords = '';
  String _partialWords = '';
  String _errorMessage = '';
  bool _showTextInput = false;
  bool _activityLaunched = false;

  StreamSubscription? _eventSub;
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();

  // Pulse animation for mic button
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _initAndStart();
  }

  Future<void> _initAndStart() async {
    // ขอ permission ไมค์
    try {
      var status = await Permission.microphone.status;
      if (!status.isGranted) {
        status = await Permission.microphone.request();
        if (!status.isGranted) {
          _startListening();
          return;
        }
      }
    } catch (e) {
      // permission_handler อาจ throw บน head unit บางรุ่น
    }

    // ตรวจสอบว่ามี Native Speech Recognizer หรือไม่
    try {
      final available = await NativeSpeechService.isAvailable();
      if (!available) {
        if (mounted) {
          setState(() {
            _errorMessage = widget.initialLocale.startsWith('th')
                ? 'อุปกรณ์นี้ไม่มีระบบค้นหาด้วยเสียง กรุณาพิมพ์ค้นหาแทน'
                : 'Voice search is not available on this device.';
            _showTextInput = true;
          });
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) _textFocusNode.requestFocus();
          });
        }
        return;
      }
    } catch (_) {
      // ลองเริ่มฟังเลย
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
        case 'activityLaunched':
          // Google Speech Dialog เปิดขึ้นแล้ว (Activity-based, แบบ YouTube)
          setState(() {
            _activityLaunched = true;
            _isListening = true;
            _errorMessage = '';
          });
          break;
        case 'error':
          final code = event['code'] as String? ?? '';
          if (code == 'WATCHDOG_TIMEOUT') break;
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

    // เริ่ม recognize — จะใช้ Activity-based (YouTube style) เป็นตัวหลัก
    NativeSpeechService.recognize(locale: widget.initialLocale)
        .then((result) {
          if (!mounted) return;
          if (result != null && result.isNotEmpty) {
            Navigator.pop(context, result);
          } else {
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
    if (code.contains('NO_RECOGNIZER') || code.contains('NO_SPEECH_ACTIVITY')) {
      return widget.initialLocale.startsWith('th')
          ? 'อุปกรณ์นี้ไม่มีระบบค้นหาด้วยเสียง กรุณาพิมพ์ค้นหาแทน'
          : 'Voice search is not available on this device.';
    }
    if (code.contains('PERMISSION_ERROR') || code.contains('INSUFFICIENT_PERMISSIONS')) {
      return widget.initialLocale.startsWith('th')
          ? 'กรุณาอนุญาตสิทธิ์การเข้าถึงไมโครโฟนในการตั้งค่าระบบ'
          : 'Please grant microphone access in system settings.';
    }
    if (code.contains('NETWORK_ERROR') || code.contains('NETWORK_TIMEOUT') || code.contains('SERVER_ERROR')) {
      return widget.initialLocale.startsWith('th')
          ? 'การเชื่อมต่อเครือข่ายขัดข้อง กรุณาตรวจสอบอินเทอร์เน็ต'
          : 'Network connection error.';
    }
    if (code.contains('NO_MATCH') || code.contains('SPEECH_TIMEOUT')) {
      return widget.initialLocale.startsWith('th')
          ? 'ตรวจไม่พบเสียงพูดของคุณ กรุณาลองใหม่อีกครั้ง'
          : 'No speech recognized. Please try again.';
    }
    if (code.contains('LANGUAGE_UNAVAILABLE') || code.contains('LANGUAGE_NOT_SUPPORTED')) {
      return widget.initialLocale.startsWith('th')
          ? 'อุปกรณ์นี้ไม่รองรับภาษาของคุณ กรุณาพิมพ์ค้นหาแทน'
          : 'Language not supported.';
    }
    return widget.initialLocale.startsWith('th')
        ? 'ไม่สามารถใช้การค้นหาด้วยเสียงได้'
        : 'Voice search failed';
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
    _pulseController.dispose();
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
    final isThai = widget.initialLocale.startsWith('th');

    return Scaffold(
      backgroundColor: const Color(0xFFE8E0E6),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header Row ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // ปุ่มปิด
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF404040),
                        size: 22,
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),

                  // YouTube-style badge
                  if (!_showTextInput)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE52116),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.mic_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isThai ? 'ค้นหาด้วยเสียง' : 'Voice Search',
                            style: const TextStyle(
                              color: Color(0xFF303030),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    const SizedBox(width: 60),

                  // ปุ่มขวา
                  if (_showTextInput)
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.mic_rounded,
                          color: Color(0xFFE52116),
                          size: 22,
                        ),
                      ),
                      onPressed: _retryListening,
                    )
                  else
                    const SizedBox(width: 60),
                ],
              ),
            ),
            const Spacer(),

            // ── Content area ──
            if (_showTextInput) ...[
              // ── โหมดพิมพ์ค้นหา ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.keyboard_rounded,
                        color: Color(0xFF505050),
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isThai ? 'พิมพ์เพื่อค้นหาเพลง' : 'Type to search songs',
                      style: const TextStyle(
                        color: Color(0xFF505050),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: const Color(0xFFE52116).withValues(alpha: 0.25),
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
                          hintText: isThai ? 'พิมพ์ชื่อเพลง...' : 'Type song name...',
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
              // ── โหมดฟังเสียง (YouTube style) ──
              Padding(
                padding: const EdgeInsets.only(left: 48, right: 48, bottom: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status text
                      Text(
                        _activityLaunched
                            ? (isThai
                                  ? 'กำลังเปิด Google Voice...'
                                  : 'Opening Google Voice...')
                            : (_isListening
                                  ? (isThai ? 'กำลังฟัง...' : 'Listening...')
                                  : (_errorMessage.isNotEmpty
                                        ? (isThai ? 'เกิดข้อผิดพลาด' : 'Error')
                                        : (isThai ? 'แตะเพื่อพูด' : 'Tap to speak'))),
                        style: TextStyle(
                          color: _errorMessage.isNotEmpty
                              ? const Color(0xFFD32F2F)
                              : const Color(0xFF1F1F1F),
                          fontSize: 32,
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
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ] else if (_errorMessage.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage,
                          style: const TextStyle(
                            color: Color(0xFF606060),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ปุ่มไมค์สีแดง (YouTube Style) พร้อม pulse animation
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer pulse ring
                    if (_isListening && !_activityLaunched)
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseAnimation.value,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFE52116).withValues(alpha: 0.1),
                              ),
                            ),
                          );
                        },
                      ),
                    // White background circle
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    // Red mic button
                    GestureDetector(
                      onTap: () {
                        if (_isListening) {
                          NativeSpeechService.stop();
                          setState(() => _isListening = false);
                        } else {
                          _startListening();
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 82,
                        height: 82,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFE52116),
                          boxShadow: _isListening
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFFE52116).withValues(alpha: 0.35),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : [],
                        ),
                        child: Icon(
                          _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                          color: Colors.white,
                          size: 42,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ปุ่มคีย์บอร์ดด้านล่าง
              GestureDetector(
                onTap: () {
                  NativeSpeechService.stop();
                  setState(() {
                    _isListening = false;
                    _showTextInput = true;
                  });
                  Future.delayed(const Duration(milliseconds: 300), () {
                    if (mounted) _textFocusNode.requestFocus();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.keyboard_rounded,
                        color: Color(0xFF606060),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isThai ? 'พิมพ์ค้นหา' : 'Type to search',
                        style: const TextStyle(
                          color: Color(0xFF606060),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Status hint
              Text(
                _isListening
                    ? (isThai ? 'แตะไมค์เพื่อหยุด' : 'Tap mic to stop')
                    : (isThai ? 'แตะไมค์เพื่อพูดอีกครั้ง' : 'Tap mic to speak again'),
                style: const TextStyle(color: Color(0xFF909090), fontSize: 12),
              ),
            ],
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }
}
