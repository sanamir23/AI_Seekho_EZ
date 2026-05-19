import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

// ⚠️ No navigation here — _AuthGate in main.dart handles routing after auth check.

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    return Scaffold(
      body: Stack(
        children: [
          // ── Yellow-to-white gradient background ──────────────────────────
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFCD24A), // EZ brand yellow
                    Color(0xFFFFEE8A), // lighter mid yellow
                    Color(0xFFFFFFFF), // white at bottom
                  ],
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),

          // ── Subtle radial highlight top-right ────────────────────────────
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topRight,
                  radius: 1.2,
                  colors: [
                    const Color(0xFFFFE033).withOpacity(0.35),
                    Colors.transparent,
                  ],
                ),
              ),
            ).animate(onPlay: (controller) => controller.repeat(reverse: true))
             .shimmer(duration: 3000.ms, color: Colors.white.withOpacity(0.2)),
          ),

          // ── Center content ────────────────────────────────────────────────
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo — transparent background, just the image + shadow
                Container(
                  width: 128,
                  height: 128,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(36),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF141414).withOpacity(0.12),
                        blurRadius: 48,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(36),
                    child: Image.asset(
                      'assets/images/ez_logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                )
                    .animate()
                    .scale(
                      begin: const Offset(0.55, 0.55),
                      end: const Offset(1.0, 1.0),
                      duration: 750.ms,
                      curve: Curves.elasticOut,
                    )
                    .fadeIn(duration: 450.ms),

                const SizedBox(height: 16),

                // Single-line brand heading
                const Text(
                  'Life Made EZ',
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 26,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF141414),
                    letterSpacing: -0.5,
                  ),
                )
                    .animate()
                    .fadeIn(delay: 420.ms, duration: 500.ms)
                    .slideY(
                      begin: 0.3,
                      end: 0,
                      delay: 420.ms,
                      duration: 500.ms,
                      curve: Curves.easeOut,
                    ),
              ],
            ),
          ),

          // ── Bottom tagline ────────────────────────────────────────────────
          Positioned(
            bottom: 56,
            left: 0,
            right: 0,
            child: const Text(
              'Your AI-powered service companion',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF888888),
                letterSpacing: 0.2,
              ),
            )
                .animate()
                .fadeIn(delay: 850.ms, duration: 500.ms),
          ),
        ],
      ),
    );
  }
}
