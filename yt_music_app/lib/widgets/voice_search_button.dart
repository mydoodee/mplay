import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import '../l10n/app_localizations.dart';

enum VoiceState { idle, listening, processing }

class VoiceSearchButton extends StatefulWidget {
  /// เรียกเมื่อได้ผลลัพธ์เสียงสำเร็จ
  final void Function(String text) onResult;

  /// เรียกเมื่อเริ่มฟัง (optional — เพื่อ clear search field)
  final VoidCallback? onListenStart;

  const VoiceSearchButton({
    super.key,
    required this.onResult,
    this.onListenStart,
  });

  @override
  State<VoiceSearchButton> createState() => _VoiceSearchButtonState();
}

class _VoiceSearchButtonState extends State<VoiceSearchButton> {
  final SpeechToText _stt = SpeechToText();
  VoiceState _state = VoiceState.idle;
  bool _sttAvailable = false;
  String _partialText = '';


  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      _sttAvailable = await _stt.initialize(
        onError: (error) => _onError(error.errorMsg),
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            _onListenDone();
          }
        },
      );
    } catch (e) {
      _sttAvailable = false;
    }
    if (mounted) setState(() {});
  }

  Future<void> _startListening() async {
    final localeStr = Localizations.localeOf(context).toString();

    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
      if (!status.isGranted) {
        _showUnavailableSnack();
        return;
      }
      await _initSpeech();
    }

    if (!mounted) return;

    if (!_sttAvailable) {
      await _initSpeech();
      if (!_sttAvailable) {
        _showUnavailableSnack();
        return;
      }
    }

    if (!mounted) return;

    widget.onListenStart?.call();

    setState(() {
      _state = VoiceState.listening;
      _partialText = '';
    });

    await _stt.listen(
      onResult: (result) {
        setState(() {
          _partialText = result.recognizedWords;
        });
        if (result.finalResult && result.recognizedWords.isNotEmpty) {
          _finishWithResult(result.recognizedWords);
        }
      },
      listenFor: const Duration(seconds: 20), // รอนานขึ้น (จาก 10 → 20 วิ)
      pauseFor: const Duration(
        seconds: 4,
      ), // รอเงียบนานขึ้น (จาก 2 → 4 วิ) เพื่อภาษาไทย
      localeId: localeStr,
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: false, // ไม่ตัดทันทีเมื่อ error — ให้ลองใหม่ได้
        listenMode: ListenMode.search, // โหมด search เหมาะกับชื่อเพลง/ศิลปิน
      ),
    );
  }

  void _stopListening() {
    _stt.stop();
    _onListenDone();
  }

  void _onListenDone() {
    if (!mounted) return;
    if (_state == VoiceState.listening) {
      if (_partialText.isNotEmpty) {
        _finishWithResult(_partialText);
      } else {
        setState(() => _state = VoiceState.idle);
      }
    }
  }

  void _finishWithResult(String text) {
    if (!mounted) return;
    setState(() => _state = VoiceState.processing);
    widget.onResult(text);
    // Reset หลังจาก 600ms
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _state = VoiceState.idle);
    });
  }

  void _onError(String error) {
    if (!mounted) return;
    setState(() => _state = VoiceState.idle);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.voiceNoSound(error)),
        backgroundColor: const Color(0xFF2A2A2A),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showUnavailableSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.voiceMicUnavailable),
        backgroundColor: const Color(0xFF2A2A2A),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleTap() {
    if (_state == VoiceState.listening) {
      _stopListening();
    } else if (_state == VoiceState.idle) {
      _startListening();
    }
  }

  @override
  void dispose() {
    _stt.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isListening = _state == VoiceState.listening;
    final isProcessing = _state == VoiceState.processing;

    return GestureDetector(
      onTap: _handleTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // วงรอบ — แสดงเฉพาะตอนกำลังฟัง, ใช้ AnimatedOpacity ไม่สั่น
          AnimatedOpacity(
            opacity: isListening ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF15A24).withValues(alpha: 0.2),
              ),
            ),
          ),

          // ปุ่มหลัก
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isListening
                  ? const Color(0xFFF15A24)
                  : isProcessing
                  ? const Color(0xFFF15A24).withValues(alpha: 0.6)
                  : Colors.transparent,
            ),
            child: Center(
              child: isProcessing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(
                      isListening ? Icons.stop_rounded : Icons.mic_rounded,
                      color: isListening
                          ? Colors.white
                          : const Color(0xFF888888),
                      size: 20,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Overlay แสดง real-time text ขณะฟังเสียง
class VoiceListeningOverlay extends StatelessWidget {
  final String partialText;
  final VoidCallback onCancel;

  const VoiceListeningOverlay({
    super.key,
    required this.partialText,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textToShow = partialText.isEmpty ? l10n.voiceListening : partialText;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0D00),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFF15A24).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.mic_rounded, color: Color(0xFFF15A24), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              textToShow,
              style: TextStyle(
                color: partialText.isEmpty
                    ? const Color(0xFF777777)
                    : Colors.white,
                fontSize: 13,
                fontStyle: partialText.isEmpty
                    ? FontStyle.italic
                    : FontStyle.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
