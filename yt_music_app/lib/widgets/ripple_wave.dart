import 'package:flutter/material.dart';

class RippleWave extends StatefulWidget {
  final Widget child;
  final Color color;

  const RippleWave({
    super.key,
    required this.child,
    this.color = const Color(0xFFF15A24),
  });

  @override
  State<RippleWave> createState() => _RippleWaveState();
}

class _RippleWaveState extends State<RippleWave> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _RipplePainter(_controller.value, widget.color),
          child: widget.child,
        );
      },
    );
  }
}

class _RipplePainter extends CustomPainter {
  final double progress;
  final Color color;

  _RipplePainter(this.progress, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width * 1.5; 

    // Draw 3 radiating rings
    for (int i = 0; i < 3; i++) {
      final currentProgress = (progress + (i * 0.33)) % 1.0;
      final currentRadius = maxRadius * currentProgress;
      
      // Opacity fades out as it expands
      final currentOpacity = (1.0 - currentProgress) * 0.4; // max opacity 0.4

      final paint = Paint()
        ..color = color.withValues(alpha: currentOpacity)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(center, currentRadius, paint);
      
      // Add a subtle border to the rings
      final borderPaint = Paint()
        ..color = color.withValues(alpha: currentOpacity * 1.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
        
      canvas.drawCircle(center, currentRadius, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RipplePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
