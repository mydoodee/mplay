import 'dart:ui';
import 'package:flutter/material.dart';
import 'dart:async';
import 'home_screen.dart';
import '../widgets/app_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Background zoom
  late AnimationController _bgController;
  late Animation<double> _bgScale;

  // Logo fade + slide up
  late AnimationController _logoController;
  late Animation<double> _logoOpacity;
  late Animation<Offset> _logoSlide;

  // Tagline fade
  late AnimationController _tagController;
  late Animation<double> _tagOpacity;

  // Bottom bar
  late AnimationController _barController;
  late Animation<double> _barOpacity;
  late Animation<double> _barWidth;

  @override
  void initState() {
    super.initState();

    // --- Background slow Ken Burns zoom ---
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );
    _bgScale = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _bgController, curve: Curves.easeInOut),
    );
    _bgController.forward();

    // --- Logo ---
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _logoOpacity = CurvedAnimation(parent: _logoController, curve: Curves.easeOut);
    _logoSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _logoController, curve: Curves.easeOut));

    // --- Tagline ---
    _tagController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _tagOpacity = CurvedAnimation(parent: _tagController, curve: Curves.easeIn);

    // --- Bottom loading bar ---
    _barController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _barOpacity = CurvedAnimation(parent: _barController, curve: Curves.easeIn);
    _barWidth = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _barController, curve: Curves.easeInOut),
    );

    // Sequence
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _logoController.forward();
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _tagController.forward();
    });
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) _barController.forward();
    });

    // Navigate
    Timer(const Duration(milliseconds: 2800), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 600),
            pageBuilder: (_, __, ___) => const HomeScreen(),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _bgController.dispose();
    _logoController.dispose();
    _tagController.dispose();
    _barController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── 1. Background photo (Ken Burns zoom + blur) ──
          AnimatedBuilder(
            animation: _bgScale,
            builder: (_, __) => Transform.scale(
              scale: _bgScale.value,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                child: Image.asset(
                  'assets/images/splash_bg.jpg',
                  fit: BoxFit.cover,
                  width: size.width,
                  height: size.height,
                ),
              ),
            ),
          ),

          // ── 2. Cinematic dark gradient overlay ──
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.25),
                  Colors.black.withValues(alpha: 0.55),
                  Colors.black.withValues(alpha: 0.88),
                  Colors.black.withValues(alpha: 0.97),
                ],
                stops: const [0.0, 0.35, 0.65, 1.0],
              ),
            ),
          ),

          // ── 3. Subtle vignette blur on edges ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: size.height * 0.45,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
              child: const SizedBox(),
            ),
          ),

          // ── 4. Content ──
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 3),

                // Logo + App name
                SlideTransition(
                  position: _logoSlide,
                  child: FadeTransition(
                    opacity: _logoOpacity,
                    child: Column(
                      children: [
                        // Glow ring around logo
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFF15A24).withValues(alpha: 0.35),
                                blurRadius: 40,
                                spreadRadius: 8,
                              ),
                            ],
                          ),
                          child: const AppLogo(size: 90, showText: false),
                        ),
                        const SizedBox(height: 20),
                        // App name with letter spacing
                        const Text(
                          'M-PLAY',
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 6,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Tagline
                FadeTransition(
                  opacity: _tagOpacity,
                  child: Column(
                    children: [
                      // Orange accent line
                      Container(
                        width: 40,
                        height: 2,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF15A24), Color(0xFFED1C24)],
                          ),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'เพลงทุกอารมณ์ ฟังได้ทุกที่',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFFCCCCCC),
                          fontWeight: FontWeight.w300,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 2),

                // Bottom loading bar
                Padding(
                  padding: const EdgeInsets.only(bottom: 48, left: 48, right: 48),
                  child: FadeTransition(
                    opacity: _barOpacity,
                    child: Column(
                      children: [
                        // Loading bar track
                        Container(
                          height: 2,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(1),
                          ),
                          child: AnimatedBuilder(
                            animation: _barWidth,
                            builder: (_, __) => FractionallySizedBox(
                              widthFactor: _barWidth.value,
                              alignment: Alignment.centerLeft,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFF15A24), Color(0xFFED1C24)],
                                  ),
                                  borderRadius: BorderRadius.circular(1),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFF15A24).withValues(alpha: 0.6),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'กำลังโหลด...',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.4),
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
