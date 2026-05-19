import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/ez_colors.dart';

const int _kMinSplashMs = 5000;

class SplashScreen extends StatefulWidget {
  final VoidCallback? onComplete;
  const SplashScreen({super.key, this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _exitCtrl;
  late final Animation<double> _exitScale;
  late final Animation<double> _exitOpacity;

  @override
  void initState() {
    super.initState();

    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _exitScale = Tween<double>(begin: 1.0, end: 0.90).animate(
      CurvedAnimation(parent: _exitCtrl, curve: Curves.easeInBack),
    );
    _exitOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitCtrl, curve: Curves.easeOut),
    );

    Future.delayed(const Duration(milliseconds: _kMinSplashMs), () {
      if (mounted) {
        _exitCtrl.forward().whenComplete(() {
          if (mounted) widget.onComplete?.call();
        });
      }
    });
  }

  @override
  void dispose() {
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    return Scaffold(
      body: Stack(
        children: [
          // ── Background gradient ──────────────────────────────────────
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFCD24A),
                    Color(0xFFFFEE8A),
                    Color(0xFFFFFBF0),
                    Color(0xFFFFFFFF),
                  ],
                  stops: [0.0, 0.38, 0.70, 1.0],
                ),
              ),
            ),
          ),

          // ── Foreground Content ────────────────────────────────────────
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _exitCtrl,
              builder: (context, child) => Transform.scale(
                scale: _exitScale.value,
                child: Opacity(opacity: _exitOpacity.value, child: child),
              ),
              child: Stack(
                children: [
                  // ── Center: logo + name + loading dots ───────────────────────
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(
                                color: EzColors.yellow.withValues(alpha: 0.55),
                                blurRadius: 36,
                                spreadRadius: 4,
                                offset: const Offset(0, 8),
                              ),
                              BoxShadow(
                                color: EzColors.ink.withValues(alpha: 0.10),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(32),
                            child: Image.asset(
                              'assets/images/ez_logo.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        )
                            .animate()
                            .scale(
                              begin: const Offset(0.35, 0.35),
                              end: const Offset(1.0, 1.0),
                              delay: 150.ms,
                              duration: 850.ms,
                              curve: Curves.elasticOut,
                            )
                            .fadeIn(delay: 150.ms, duration: 400.ms),

                        const SizedBox(height: 28),

                        // Brand name
                        Text(
                          'Life Made EZ',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            color: EzColors.ink,
                            letterSpacing: -0.8,
                          ),
                        )
                            .animate()
                            .fadeIn(delay: 850.ms, duration: 500.ms)
                            .slideY(
                              begin: 0.3,
                              end: 0,
                              delay: 850.ms,
                              duration: 500.ms,
                              curve: Curves.easeOutCubic,
                            ),

                        const SizedBox(height: 14),

                        // Loading dots
                        _AnimatedDots()
                            .animate()
                            .fadeIn(delay: 1050.ms, duration: 400.ms),
                      ],
                    ),
                  ),

                  // ── Bottom: tagline ──────────────────────────────────────────
                  Positioned(
                    bottom: 56,
                    left: 0,
                    right: 0,
                    child: Column(
                      children: [
                        // Accent line
                        Container(
                          width: 36,
                          height: 2,
                          decoration: BoxDecoration(
                            color: EzColors.yellowDeep,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        )
                            .animate()
                            .fadeIn(delay: 1300.ms, duration: 400.ms)
                            .scaleX(
                              begin: 0,
                              end: 1,
                              delay: 1300.ms,
                              duration: 400.ms,
                              curve: Curves.easeOut,
                            ),

                        const SizedBox(height: 10),

                        // Tagline
                        Text(
                          'Your AI-powered service companion',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: EzColors.muted,
                            letterSpacing: 0.2,
                          ),
                        )
                            .animate()
                            .fadeIn(delay: 1400.ms, duration: 500.ms)
                            .slideY(
                              begin: 0.4,
                              end: 0,
                              delay: 1400.ms,
                              duration: 500.ms,
                              curve: Curves.easeOutCubic,
                            ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bouncing dots ────────────────────────────────────────────────────────────
class _AnimatedDots extends StatefulWidget {
  @override
  State<_AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<_AnimatedDots>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 480),
      ),
    );
    _anims = _controllers
        .map((c) => Tween<double>(begin: 0, end: -6).animate(
              CurvedAnimation(parent: c, curve: Curves.easeInOut),
            ))
        .toList();

    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) {
          _controllers[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _anims[i],
          builder: (_, __) => Transform.translate(
            offset: Offset(0, _anims[i].value),
            child: Container(
              width: 5,
              height: 5,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: EzColors.yellowDeep,
              ),
            ),
          ),
        );
      }),
    );
  }
}
