import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final Color? color;

  const AppLogo({
    super.key,
    this.size = 24,
    this.showText = true,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    // If showText is false (used for tiny icons), just show 'm'
    if (!showText) {
      return Text(
        'm',
        style: TextStyle(
          fontSize: size * 1.2,
          fontWeight: FontWeight.w600,
          color: color ?? const Color(0xFFFF9800), // Orange/Amber
          letterSpacing: -0.5,
        ),
      );
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: size * 1.2, // Adjust font scale to match previous image height feel
          fontWeight: FontWeight.w600,
          fontFamily: 'Roboto', // Clean sans-serif font
          letterSpacing: -0.5,
        ),
        children: [
          TextSpan(
            text: 'm',
            style: TextStyle(
              color: color ?? const Color(0xFFFFA000), // Rich Yellow/Orange
            ),
          ),
          TextSpan(
            text: 'PLAY',
            style: TextStyle(
              color: color ?? const Color(0xFFFF3D00), // Vibrant Red-Orange
            ),
          ),
        ],
      ),
    );
  }
}
