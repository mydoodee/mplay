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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _GlowingRingPainter(_controller.value, widget.color),
          child: Padding(
            padding: const EdgeInsets.all(2.0), // ระยะห่างจากกล่องด้านในนิดนึง
            child: widget.child,
          ),
        );
      },
    );
  }
}

class _GlowingRingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _GlowingRingPainter(this.progress, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    
    final center = Offset(size.width / 2, size.height / 2);
    // รัศมีของวงกลม (วาดให้อยู่ขอบของ Widget)
    final radius = (math.min(size.width, size.height) / 2);

    // เส้นวงกลมด้านหลัง (Track) สีเทาเข้มๆ
    final trackPaint = Paint()
      ..color = const Color(0xFF1E1E1E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    canvas.drawCircle(center, radius, trackPaint);

    final startAngle = progress * 2 * math.pi;

    // การไล่สี (Gradient) แบบเส้นดาวตก หางจาง หัวสว่าง
    final sweepGradient = SweepGradient(
      colors: [
        color.withValues(alpha: 0.0), // หางจางหายไป
        color.withValues(alpha: 0.8), // ตัวเส้น
        Colors.white,                 // หัวเส้นไฟสีสว่างสุด
      ],
      stops: const [0.4, 0.95, 1.0], // หัวเส้นเล็กๆ พุ่งนำ
      transform: GradientRotation(startAngle),
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
  bool shouldRepaint(covariant _GlowingRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
