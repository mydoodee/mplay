import 'package:flutter/material.dart';

class MiniEqualizer extends StatefulWidget {
  final Color color;
  final double size;

  const MiniEqualizer({
    super.key,
    this.color = const Color(0xFFF15A24),
    this.size = 14.0,
  });

  @override
  State<MiniEqualizer> createState() => _MiniEqualizerState();
}

class _MiniEqualizerState extends State<MiniEqualizer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildBar(0),
          _buildBar(1),
          _buildBar(2),
        ],
      ),
    );
  }

  Widget _buildBar(int index) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Different phase and scale for each bar to make it look random
        double scale = 0.3;
        final value = _controller.value;
        if (index == 0) {
          scale = 0.4 + 0.6 * value;
        } else if (index == 1) {
          scale = 0.3 + 0.7 * (1.0 - value);
        } else if (index == 2) {
          double val = (value + 0.5) % 1.0;
          if (val > 0.5) val = 1.0 - val;
          scale = 0.3 + 1.4 * val;
        }

        return Container(
          width: widget.size * 0.22,
          height: widget.size * scale,
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(1),
          ),
        );
      },
    );
  }
}
