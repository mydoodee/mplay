import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../l10n/app_localizations.dart';
import '../services/native_speech_service.dart';

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
  bool _showTextInput = false; // true = แสดงช่องพิมพ์ค้นหาแทน
  double _rmsLevel = 0.0;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;
  StreamSubscription? _eventSub;
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initAndStart();
  }

  Future<void> _initAndStart() async {
    // ขอ permission ไมค์ก่อน
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
      if (!status.isGranted) {
        if (mounted) {
          setState(() {
            _errorMessage = 'จำเป็นต้องอนุญาตสิทธิ์การใช้ไมโครโฟน';
            _showTextInput = true;
          });
        }
        return;
      }
    }

    // เช็คว่ามี recognizer พร้อมใช้งานไหม
    final available = await NativeSpeechService.isAvailable();
    if (!available) {
      if (mounted) {
        // ไม่มี recognizer → เปิดโหมดพิมพ์ค้นหาเลย ไม่ต้องให้ผู้ใช้ไปตั้งค่าอะไร
        setState(() {
          _showTextInput = true;
        });
        // Focus ที่ช่องพิมพ์
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _textFocusNode.requestFocus();
        });
      }
      return;
    }

    // มี recognizer → เริ่มฟัง
    _startListening();
  }

  void _startListening() {
    setState(() {
      _isListening = true;
      _recognizedWords = '';
      _partialWords = '';
      _errorMessage = '';
    });

    // Subscribe to speech events
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
          final value = event['value'];
          if (value is num) {
            setState(() {
              _rmsLevel = value.toDouble().clamp(-2.0, 12.0);
            });
          }
          break;
        case 'error':
          final code = event['code'] as String? ?? '';
          if (code == 'NO_MATCH' || code == 'SPEECH_TIMEOUT') {
            // ไม่พูดอะไร → เปิดโหมดพิมพ์
            setState(() {
              _isListening = false;
              _showTextInput = true;
            });
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) _textFocusNode.requestFocus();
            });
          } else {
            setState(() {
              _isListening = false;
              _errorMessage = 'เกิดข้อผิดพลาด: $code';
              _showTextInput = true;
            });
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) _textFocusNode.requestFocus();
            });
          }
          break;
        case 'speechEnd':
          setState(() => _isListening = false);
          break;
      }
    });

    // เริ่ม recognize
    NativeSpeechService.recognize(
      locale: widget.initialLocale,
    ).then((result) {
      if (!mounted) return;
      if (result != null && result.isNotEmpty) {
        // สำเร็จ! ส่งผลลัพธ์กลับไป
        Navigator.pop(context, result);
      } else {
        // ไม่มีผลลัพธ์ → เปิดโหมดพิมพ์
        setState(() {
          _isListening = false;
          _showTextInput = true;
        });
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _textFocusNode.requestFocus();
        });
      }
    }).catchError((e) {
      if (!mounted) return;
      if (e is PlatformException && e.code == 'NO_RECOGNIZER') {
        // ไม่มี recognizer → เปิดโหมดพิมพ์
        setState(() {
          _isListening = false;
          _showTextInput = true;
        });
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _textFocusNode.requestFocus();
        });
      } else {
        setState(() {
          _isListening = false;
          _errorMessage = 'เกิดข้อผิดพลาด: $e';
          _showTextInput = true;
        });
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _textFocusNode.requestFocus();
        });
      }
    });
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
    final l10n = AppLocalizations.of(context)!;
    final displayText = _recognizedWords.isNotEmpty
        ? _recognizedWords
        : (_partialWords.isNotEmpty ? _partialWords : '');

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.95),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // ปุ่มสลับ keyboard / mic
                  if (!_isListening)
                    IconButton(
                      icon: Icon(
                        _showTextInput ? Icons.mic_rounded : Icons.keyboard_rounded,
                        color: const Color(0xFF888888),
                        size: 26,
                      ),
                      onPressed: () async {
                        if (_showTextInput) {
                          // สลับไปใช้ไมค์
                          final avail = await NativeSpeechService.isAvailable();
                          if (avail) {
                            _retryListening();
                          } else {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'ไมโครโฟนไม่พร้อมใช้งานบนอุปกรณ์นี้',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  backgroundColor: Color(0xFF333333),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          }
                        } else {
                          // สลับไปใช้ keyboard
                          setState(() => _showTextInput = true);
                          Future.delayed(const Duration(milliseconds: 300), () {
                            if (mounted) _textFocusNode.requestFocus();
                          });
                        }
                      },
                    )
                  else
                    const SizedBox(width: 48),
                  // ปุ่มปิด
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Spacer(),

            // ── Content ──
            if (_showTextInput) ...[
              // ── โหมดพิมพ์ค้นหา ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    const Icon(
                      Icons.keyboard_rounded,
                      color: Color(0xFF555555),
                      size: 40,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.voiceListening,
                      style: const TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFF15A24).withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                      child: TextField(
                        controller: _textController,
                        focusNode: _textFocusNode,
                        textInputAction: TextInputAction.search,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                        decoration: InputDecoration(
                          hintText: 'พิมพ์ชื่อเพลง...',
                          hintStyle: const TextStyle(
                            color: Color(0xFF555555),
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
                              color: Color(0xFFF15A24),
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
                          color: Color(0xFF888888),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ] else ...[
              // ── โหมดฟังเสียง ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  displayText.isEmpty ? l10n.voiceListening : displayText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: displayText.isEmpty ? Colors.grey : Colors.white,
                    fontSize: displayText.isEmpty ? 18 : 24,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 50),
              // Mic button with pulse + RMS visualization
              GestureDetector(
                onTap: () {
                  if (_isListening) {
                    NativeSpeechService.stop();
                    setState(() => _isListening = false);
                  } else {
                    _startListening();
                  }
                },
                child: AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (context, child) {
                    // ขนาด pulse ตาม RMS level ของเสียง
                    final rmsScale = _isListening
                        ? 1.0 + (_rmsLevel.clamp(0, 10) / 10.0) * 0.5
                        : _pulseAnim.value;

                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // วงแหวนด้านนอก — สะท้อนระดับเสียง
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 100),
                          width: 100 * rmsScale,
                          height: 100 * rmsScale,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFF15A24)
                                .withValues(alpha: _isListening ? 0.2 : 0.1),
                          ),
                        ),
                        // ปุ่มไมค์หลัก
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isListening
                                ? const Color(0xFFF15A24)
                                : const Color(0xFF333333),
                            boxShadow: _isListening
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFFF15A24)
                                          .withValues(alpha: 0.4),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Icon(
                            _isListening ? Icons.mic : Icons.mic_none,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _isListening ? l10n.voiceTapToStop : 'แตะเพื่อพูดอีกครั้ง',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }
}
