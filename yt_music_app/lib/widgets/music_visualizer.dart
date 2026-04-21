import 'dart:math' as math;
import 'package:flutter/material.dart';

class MusicVisualizer extends StatefulWidget {
  final bool isPlaying;
  final Color color;
  final double maxHeight;
  final int barCount;

  const MusicVisualizer({
    super.key,
    required this.isPlaying,
    this.color = const Color(0xFFF15A24),
    this.barCount = 7,
    this.maxHeight = 60.0,
  });

  @override
  State<MusicVisualizer> createState() => _MusicVisualizerState();
}

class _MusicVisualizerState extends State<MusicVisualizer>
    with TickerProviderStateMixin {
  late AnimationController _phaseController;
  late AnimationController _amplitudeController;
  late Animation<double> _amplitudeAnimation;

  @override
  void initState() {
    super.initState();

    _phaseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4), // Slower for smoother movement
    )..repeat();

    _amplitudeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _amplitudeAnimation = CurvedAnimation(
      parent: _amplitudeController,
      curve: Curves.easeInOutQuart,
    );

    if (widget.isPlaying) {
      _amplitudeController.forward();
    } else {
      _amplitudeController.value = 0.05;
    }
  }

  @override
  void didUpdateWidget(MusicVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _amplitudeController.forward();
      } else {
        _amplitudeController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _phaseController.dispose();
    _amplitudeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_phaseController, _amplitudeAnimation]),
      builder: (context, child) {
        return CustomPaint(
          size: Size(
            MediaQuery.of(context).size.width * 0.75,
            widget.maxHeight,
          ),
          painter: MultiWavePainter(
            color: widget.color.withValues(alpha: widget.isPlaying ? 1.0 : 0.3),
            phase: _phaseController.value,
            amplitude: _amplitudeAnimation.value,
          ),
        );
      },
    );
  }
}

class MultiWavePainter extends CustomPainter {
  final Color color;
  final double phase;
  final double amplitude;

  MultiWavePainter({
    required this.color,
    required this.phase,
    required this.amplitude,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw 3 layers of waves for depth and "music" feel
    _drawWave(
      canvas,
      size,
      color.withValues(alpha: 0.15),
      1.0,
      phase,
      1.2,
      0.4,
      1.5,
    ); // Bottom faint
    _drawWave(
      canvas,
      size,
      color.withValues(alpha: 0.4),
      1.5,
      phase + 0.3,
      2.2,
      0.6,
      2.0,
    ); // Middle
    _drawWave(
      canvas,
      size,
      color,
      3.0,
      phase - 0.2,
      1.8,
      0.8,
      3.0,
      hasGlow: true,
    ); // Top Main
  }

  void _drawWave(
    Canvas canvas,
    Size size,
    Color waveColor,
    double strokeWidth,
    double wavePhase,
    double frequency,
    double heightScale,
    double glowSize, {
    bool hasGlow = false,
  }) {
    final paint = Paint()
      ..color = waveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    if (hasGlow) {
      // Layered glow for "Neon" effect
      for (int i = 1; i <= 3; i++) {
        final glowPaint = Paint()
          ..color = waveColor.withValues(alpha: 0.2 / i)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth + (i * 4)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, i * 4.0);

        canvas.drawPath(
          _createWavePath(size, wavePhase, frequency, heightScale),
          glowPaint,
        );
      }
    }

    canvas.drawPath(
      _createWavePath(size, wavePhase, frequency, heightScale),
      paint,
    );
  }

  Path _createWavePath(
    Size size,
    double wavePhase,
    double frequency,
    double heightScale,
  ) {
    final path = Path();
    final halfHeight = size.height / 2;
    final width = size.width;

    for (double x = 0; x <= width; x += 1) {
      final normalizedX = x / width;

      // Tapering factor (0 at ends, 1 at center)
      final taperFactor = math.pow(math.sin(normalizedX * math.pi), 1.5);

      // Primary sine wave
      final sineFactor = math.sin(
        normalizedX * 2 * math.pi * frequency - wavePhase * 2 * math.pi,
      );

      // Secondary harmonic to avoid "worm" look
      final secondarySine = math.sin(
        normalizedX * 4 * math.pi * 1.5 + wavePhase * 3 * math.pi,
      );

      final y =
          halfHeight +
          (sineFactor * 0.75 + secondarySine * 0.25) *
              (size.height * 0.4) *
              amplitude *
              heightScale *
              taperFactor;

      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant MultiWavePainter oldDelegate) {
    return oldDelegate.phase != phase || oldDelegate.amplitude != amplitude;
  }
}
