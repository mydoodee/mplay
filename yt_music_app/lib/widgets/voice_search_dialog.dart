import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';
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
  // Fallback: speech_to_text (ใช้เมื่อ native intent ล้มเหลว)
  final SpeechToText _stt = SpeechToText();
  bool _isListening = false;
  String _recognizedWords = '';
  String _errorMessage = '';
  bool _showSettingsButton = false;
  bool _usingFallback = false; // true = กำลังใช้ speech_to_text fallback
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

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
    // ────────────────────────────────────────────────
    //  ลอง Native Intent ก่อน (เหมือน YouTube)
    // ────────────────────────────────────────────────
    try {
      final result = await NativeSpeechService.recognize(
        locale: widget.initialLocale,
        prompt: '', // ไม่แสดง prompt เพิ่มเติม — ให้ native UI จัดการ
      );

      if (!mounted) return;

      if (result != null && result.isNotEmpty) {
        // สำเร็จ! ส่งผลลัพธ์กลับไป
        Navigator.pop(context, result);
        return;
      } else {
        // ผู้ใช้กดยกเลิก → ปิด dialog
        Navigator.pop(context);
        return;
      }
    } on PlatformException catch (e) {
      // Native intent ไม่พร้อมใช้งาน → fallback ไป speech_to_text
      debugPrint('Native speech failed (${e.code}): ${e.message}');
      if (!mounted) return;
      _startFallback();
    } catch (e) {
      debugPrint('Native speech error: $e');
      if (!mounted) return;
      _startFallback();
    }
  }

  // ────────────────────────────────────────────────
  //  Fallback: ใช้ speech_to_text package (เดิม)
  // ────────────────────────────────────────────────
  Future<void> _startFallback() async {
    setState(() => _usingFallback = true);

    try {
      var status = await Permission.microphone.status;
      if (!status.isGranted) {
        status = await Permission.microphone.request();
        if (!status.isGranted) {
          if (mounted) {
            setState(() {
              _errorMessage = 'จำเป็นต้องอนุญาตสิทธิ์การใช้ไมโครโฟน\nเพื่อใช้ฟังก์ชันการค้นหาด้วยเสียง';
              _showSettingsButton = true;
              _isListening = false;
            });
          }
          return;
        }
      }

      bool available = await _stt.initialize(
        onError: (errorNotification) {
          if (mounted) {
            setState(() {
              _errorMessage = 'เกิดข้อผิดพลาด: ${errorNotification.errorMsg}\n(รหัสข้อผิดพลาด: ${errorNotification.permanent ? "ถาวร" : "ชั่วคราว"})';
              _isListening = false;
            });
          }
        },
        onStatus: (status) {
          if (status == 'notListening') {
            if (mounted && _recognizedWords.isNotEmpty) {
              Navigator.pop(context, _recognizedWords);
            }
          }
        },
      );

      if (available) {
        _startListening();
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'ระบบค้นหาด้วยเสียงไม่พร้อมใช้งานบนจอรถยนต์นี้\n\n'
                'วิธีแก้ไข:\n'
                '1. ติดตั้งแอป "Google" หรือ "Speech Services by Google" จาก Play Store\n'
                '2. ไปที่ ตั้งค่า (Settings) ของจอรถยนต์ -> ภาษาและการป้อนข้อมูล (Languages & Input) -> ป้อนข้อมูลด้วยเสียง (Voice Input) และเลือก Google เป็นบริการเริ่มต้น';
            _isListening = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          final errStr = e.toString();
          if (errStr.contains('recognizerNotAvailable') ||
              errStr.contains('Speech recognition not available')) {
            _errorMessage = 'ระบบค้นหาด้วยเสียงไม่พร้อมใช้งานบนจอรถยนต์นี้\n\n'
                'วิธีแก้ไข:\n'
                '1. ติดตั้งแอป "Google" หรือ "Speech Services by Google" จาก Play Store\n'
                '2. ไปที่ ตั้งค่า (Settings) ของจอรถยนต์ -> ภาษาและการป้อนข้อมูล (Languages & Input) -> ป้อนข้อมูลด้วยเสียง (Voice Input) และเลือก Google เป็นบริการเริ่มต้น';
          } else {
            _errorMessage = 'เกิดข้อผิดพลาดในการเชื่อมต่อไมค์: $e';
          }
          _isListening = false;
        });
      }
    }
  }

  void _startListening() async {
    setState(() {
      _isListening = true;
      _recognizedWords = '';
      _errorMessage = '';
    });

    await _stt.listen(
      onResult: (result) {
        setState(() {
          _recognizedWords = result.recognizedWords;
        });
        if (result.finalResult && result.recognizedWords.isNotEmpty) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) Navigator.pop(context, result.recognizedWords);
          });
        }
      },
      localeId: widget.initialLocale,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 5),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _stt.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // ถ้ากำลังใช้ native intent → แสดงหน้าจอรอ (native UI จะแสดงทับ)
    if (!_usingFallback) {
      return Scaffold(
        backgroundColor: Colors.black.withValues(alpha: 0.9),
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const Spacer(),
              const CircularProgressIndicator(
                color: Color(0xFFF15A24),
                strokeWidth: 2.5,
              ),
              const SizedBox(height: 20),
              Text(
                l10n.voiceListening,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      );
    }

    // ──── Fallback UI (speech_to_text) ────
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.9),
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _errorMessage.isNotEmpty
                    ? _errorMessage
                    : (_recognizedWords.isEmpty ? l10n.voiceListening : _recognizedWords),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _errorMessage.isNotEmpty
                      ? Colors.orangeAccent
                      : (_recognizedWords.isEmpty ? Colors.grey : Colors.white),
                  fontSize: _errorMessage.isNotEmpty ? 15 : 24,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
            ),
            if (_showSettingsButton) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => openAppSettings(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF15A24),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                icon: const Icon(Icons.settings),
                label: const Text(
                  'เปิดการตั้งค่าของแอป',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ],
            const SizedBox(height: 50),
            if (_errorMessage.isEmpty)
              GestureDetector(
                onTap: () {
                  if (_isListening) {
                    _stt.stop();
                  } else {
                    _startListening();
                  }
                },
                child: AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (context, child) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 100 * _pulseAnim.value,
                          height: 100 * _pulseAnim.value,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(
                              0xFFF15A24,
                            ).withValues(alpha: 0.15),
                          ),
                        ),
                        Container(
                          width: 80,
                          height: 80,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFF15A24),
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
            const SizedBox(height: 30),
            if (_errorMessage.isEmpty)
              Text(
                l10n.voiceTapToStop,
                style: const TextStyle(color: Colors.grey),
              ),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }
}
