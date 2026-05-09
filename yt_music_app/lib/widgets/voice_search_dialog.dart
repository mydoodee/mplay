import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../l10n/app_localizations.dart';

class VoiceSearchDialog extends StatefulWidget {
  final String initialLocale;
  const VoiceSearchDialog({super.key, required this.initialLocale});

  @override
  State<VoiceSearchDialog> createState() => _VoiceSearchDialogState();
}

class _VoiceSearchDialogState extends State<VoiceSearchDialog>
    with SingleTickerProviderStateMixin {
  final SpeechToText _stt = SpeechToText();
  bool _isListening = false;
  String _recognizedWords = '';
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
    bool available = await _stt.initialize(
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
    }
  }

  void _startListening() async {
    setState(() {
      _isListening = true;
      _recognizedWords = '';
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
            Text(
              _recognizedWords.isEmpty ? l10n.voiceListening : _recognizedWords,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _recognizedWords.isEmpty ? Colors.grey : Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 50),
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
                          color: const Color(0xFFF15A24).withValues(alpha: 0.15),
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
            Text(
              l10n.voiceTapToStop, // หรือข้อความอื่นๆ เช่น "Tap to speak"
              style: const TextStyle(color: Colors.grey),
            ),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }
}
