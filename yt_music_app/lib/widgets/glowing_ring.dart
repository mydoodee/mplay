import 'dart:math' as math;
import 'package:flutter/material.dart';

class GlowingRing extends StatefulWidget {
  final Widget child;
  final Color color;

  const GlowingRing({
    super.key,
    required this.child,
    this.color = const Color(0xFFF15A24),
  });

  @override
  State<GlowingRing> createState() => _GlowingRingState();
}

class _GlowingRingState extends State<GlowingRing> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4), // ความเร็วเส้นไฟวิ่ง (ช้าลง นิ่มนวลขึ้น)
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Optimize performance by avoiding rebuild of MaskFilter.blur every frame.
    // We draw the static glowing ring once and simply rotate it using GPU hardware acceleration.
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: RotationTransition(
            turns: _controller,
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _StaticGlowingRingPainter(widget.color),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(2.0), // ระยะห่างจากกล่องด้านในนิดนึง
          child: widget.child,
        ),
      ],
    );
  }
}

class _StaticGlowingRingPainter extends CustomPainter {
  final Color color;

  _StaticGlowingRingPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    
    final center = Offset(size.width / 2, size.height / 2);
    // รัศมีของวงกลม (วาดให้อยู่ขอบของ Widget)
    final radius = (math.min(size.width, size.height) / 2);

    // เส้นวงกลมด้านหลัง (Track) สีเทาเข้มๆ (หมุนไปก็ไม่เห็นความต่าง)
    final trackPaint = Paint()
      ..color = const Color(0xFF1E1E1E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    canvas.drawCircle(center, radius, trackPaint);

    // การไล่สี (Gradient) แบบเส้นดาวตก หางจาง หัวสว่าง
    final sweepGradient = SweepGradient(
      colors: [
        color.withValues(alpha: 0.0), // หางจางหายไป
        color.withValues(alpha: 0.8), // ตัวเส้น
        Colors.white,                 // หัวเส้นไฟสีสว่างสุด
      ],
      stops: const [0.4, 0.95, 1.0], // หัวเส้นเล็กๆ พุ่งนำ
    );

    // แปรงสำหรับแสงฟุ้ง (Glow Effect)
    final blurPaint = Paint()
      ..shader = sweepGradient.createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0); // แสงฟุ้งกระจายขอบ

    // แปรงสำหรับเส้นไฟแกนกลาง (Core)
    final linePaint = Paint()
      ..shader = sweepGradient.createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    // วาดแสงฟุ้ง (Glow)
    canvas.drawCircle(center, radius, blurPaint);

    // วาดเส้นแกนหลัก (Core line) ทับแสงฟุ้ง
    canvas.drawCircle(center, radius, linePaint);
  }

  @override
  bool shouldRepaint(covariant _StaticGlowingRingPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
