import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/ez_colors.dart';
import '../../core/widgets/ez_chip.dart';
import '../../core/widgets/bottom_nav_bar.dart';
import '../../core/services/api_service.dart';
import '../composer/chat_screen.dart';
import '../auth/auth_screen.dart';
import 'bookings_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _activeChip = 0;
  int _activeNavIndex = 0;

  String _displayName = 'Ahmad';

  final _services = const [
    _ServiceChip(Icons.ac_unit_rounded, 'AC Repair'),
    _ServiceChip(Icons.plumbing_rounded, 'Plumber'),
    _ServiceChip(Icons.bolt_rounded, 'Electrician'),
    _ServiceChip(Icons.menu_book_rounded, 'Tutor'),
    _ServiceChip(Icons.content_cut_rounded, 'Beautician'),
    _ServiceChip(Icons.cleaning_services_rounded, 'Cleaning'),
  ];

  final _popular = const [
    _PopularItem('AC Service', 'from ₨1,500', 'Today', Color(0xFFFCD24A),
        Icons.ac_unit_rounded),
    _PopularItem('Plumbing', 'from ₨800', '2hr ETA', Color(0xFFFFE988),
        Icons.plumbing_rounded),
    _PopularItem('Deep Clean', 'from ₨3,500', 'Tomorrow', Color(0xFFF4EFE2),
        Icons.cleaning_services_rounded),
    _PopularItem('Maths Tutor', 'from ₨1,200/hr', 'Verified', Color(0xFFFFF5C2),
        Icons.menu_book_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final dn = await ApiService.instance.getSavedDisplayName();
    final email = await ApiService.instance.getSavedEmail();
    if (mounted) {
      setState(() {
        if (dn != null && dn.isNotEmpty) {
          _displayName = dn.split(' ').first;
        } else if (email != null) {
          _displayName = email.split('@').first;
        }
      });
    }
  }

  void _logout() async {
    await ApiService.instance.clearSession();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (r) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: EzColors.cream,
      body: Column(
        children: [
          Expanded(
            child: _activeNavIndex == 1
                ? const BookingsTab()
                : CustomScrollView(
                    slivers: [
                      // Ambient header background
                      SliverToBoxAdapter(
                        child: Stack(
                          children: [
                            // Ambient gradient
                            Container(
                              height: 220,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xFFFFE988),
                                    Color(0xFFFBF8F1)
                                  ],
                                ),
                              ),
                            ),
                            // Subtle house silhouettes
                            Positioned.fill(
                              child: CustomPaint(painter: _AmbientPainter()),
                            ),
                            // Header + greeting on top
                            SafeArea(
                              bottom: false,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // ── Top bar ──
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 18, vertical: 10),
                                    child: Row(
                                      children: [
                                        // Location pill
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: EzColors.white,
                                            borderRadius:
                                                BorderRadius.circular(999),
                                            border: Border.all(
                                                color: EzColors.border,
                                                width: 1),
                                            boxShadow: [
                                              BoxShadow(
                                                color: EzColors.ink
                                                    .withValues(alpha: 0.04),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              )
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.location_pin,
                                                  size: 14,
                                                  color: EzColors.ink),
                                              const SizedBox(width: 5),
                                              Text('G-13, Islamabad',
                                                  style: GoogleFonts
                                                      .plusJakartaSans(
                                                          fontSize: 12.5,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: EzColors.ink)),
                                              const SizedBox(width: 4),
                                              const Icon(
                                                  Icons.keyboard_arrow_down,
                                                  size: 14,
                                                  color: EzColors.muted),
                                            ],
                                          ),
                                        ),
                                        const Spacer(),
                                        // Bell
                                        _IconCircleBtn(
                                          child: Stack(
                                            children: [
                                              const Icon(
                                                  Icons.notifications_outlined,
                                                  size: 20,
                                                  color: EzColors.ink),
                                              Positioned(
                                                top: 1,
                                                right: 1,
                                                child: Container(
                                                  width: 7,
                                                  height: 7,
                                                  decoration: BoxDecoration(
                                                    color: EzColors.yellowDeep,
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                        color: EzColors.white,
                                                        width: 1.5),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Avatar (long press = logout)
                                        GestureDetector(
                                          onLongPress: _logout,
                                          child: Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  Color(0xFFFCD24A),
                                                  Color(0xFFE8B617)
                                                ],
                                              ),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                  color: EzColors.white,
                                                  width: 2),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: EzColors.ink
                                                      .withValues(alpha: 0.06),
                                                  blurRadius: 6,
                                                )
                                              ],
                                            ),
                                            child: Center(
                                              child: Text(
                                                  _displayName.isNotEmpty
                                                      ? _displayName[0]
                                                          .toUpperCase()
                                                      : 'E',
                                                  style: GoogleFonts
                                                      .plusJakartaSans(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          color: EzColors.ink)),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ).animate().fadeIn(duration: 400.ms).slideY(
                                      begin: -0.2, end: 0, duration: 400.ms),

                                  // ── Greeting ──
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        20, 14, 20, 4),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        RichText(
                                          text: TextSpan(
                                            style: GoogleFonts.plusJakartaSans(
                                                fontSize: 13,
                                                color: EzColors.inkSoft,
                                                fontWeight: FontWeight.w500),
                                            children: [
                                              const TextSpan(
                                                  text: 'Assalam-o-Alaikum, '),
                                              TextSpan(
                                                text: _displayName,
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: EzColors.ink),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'How can we assist\nyou today?',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 27,
                                            fontWeight: FontWeight.w700,
                                            color: EzColors.ink,
                                            letterSpacing: -0.6,
                                            height: 1.15,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                      .animate()
                                      .fadeIn(delay: 100.ms, duration: 400.ms)
                                      .slideY(
                                          begin: 0.2,
                                          end: 0,
                                          duration: 400.ms,
                                          delay: 100.ms),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── Search bar ──
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: GestureDetector(
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const ChatScreen())),
                            child: Container(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 14, 10, 14),
                              decoration: BoxDecoration(
                                color: EzColors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: EzColors.border, width: 1),
                                boxShadow: [
                                  BoxShadow(
                                    color: EzColors.ink.withValues(alpha: 0.04),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                  BoxShadow(
                                    color: EzColors.ink.withValues(alpha: 0.08),
                                    blurRadius: 28,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: EzColors.yellow,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                        Icons.auto_awesome_rounded,
                                        size: 16,
                                        color: EzColors.ink),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _TypingText(
                                          text: 'Apko konsi service chahiyay?',
                                          style: GoogleFonts.plusJakartaSans(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w600,
                                              color: EzColors.ink),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Type or say it — Urdu, English, Roman',
                                          style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11.5,
                                              color: EzColors.muted,
                                              fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: EzColors.white,
                                      shape: BoxShape.circle,
                                      border:
                                          Border.all(color: EzColors.border),
                                    ),
                                    child: const Icon(Icons.mic_rounded,
                                        size: 16, color: EzColors.ink),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: EzColors.ink,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: EzColors.ink
                                              .withValues(alpha: 0.18),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        )
                                      ],
                                    ),
                                    child: const Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 16,
                                        color: EzColors.yellow),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                            .animate()
                            .fadeIn(delay: 200.ms, duration: 400.ms)
                            .slideY(
                                begin: 0.15,
                                end: 0,
                                delay: 200.ms,
                                duration: 400.ms),
                      ),

                      // ── Quick services ──
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 18, 20, 10),
                              child: Row(
                                children: [
                                  Text('Quick services',
                                      style: GoogleFonts.plusJakartaSans(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: EzColors.ink)),
                                  const Spacer(),
                                  Text('See all',
                                      style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: EzColors.muted)),
                                ],
                              ),
                            ),
                            SizedBox(
                              height: 44,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: _services.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (_, i) => EzChip(
                                  label: _services[i].label,
                                  iconData: _services[i].icon,
                                  active: i == _activeChip,
                                  onTap: () => setState(() => _activeChip = i),
                                ),
                              ),
                            ),
                          ],
                        ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
                      ),

                      // ── Popular near you ──
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text('Popular near you',
                                      style: GoogleFonts.plusJakartaSans(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: EzColors.ink)),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: EzColors.yellowGlow,
                                      borderRadius: BorderRadius.circular(999),
                                      border:
                                          Border.all(color: EzColors.yellow),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.auto_awesome_rounded,
                                            size: 10, color: EzColors.ink),
                                        const SizedBox(width: 4),
                                        Text('AI ranked',
                                            style: GoogleFonts.plusJakartaSans(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700,
                                                color: EzColors.inkSoft)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              GridView.count(
                                crossAxisCount: 2,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: 1.15,
                                children: _popular
                                    .map((p) => _PopularCard(item: p))
                                    .toList(),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 350.ms, duration: 400.ms),
                      ),
                    ],
                  ),
          ),

          // ── Bottom nav ──
          EzBottomNav(
            activeIndex: _activeNavIndex,
            onTap: (i) => setState(() => _activeNavIndex = i),
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ───────────────────────────────────────────────────

class _IconCircleBtn extends StatelessWidget {
  final Widget child;
  const _IconCircleBtn({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: EzColors.white,
        shape: BoxShape.circle,
        border: Border.all(color: EzColors.border),
        boxShadow: [
          BoxShadow(
              color: EzColors.ink.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Center(child: child),
    );
  }
}

class _ServiceChip {
  final IconData icon;
  final String label;
  const _ServiceChip(this.icon, this.label);
}

class _PopularItem {
  final String title;
  final String subtitle;
  final String tag;
  final Color color;
  final IconData icon;
  const _PopularItem(
      this.title, this.subtitle, this.tag, this.color, this.icon);
}

class _PopularCard extends StatelessWidget {
  final _PopularItem item;
  const _PopularCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      decoration: BoxDecoration(
        color: EzColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: EzColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: EzColors.ink.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: item.color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, size: 20, color: EzColors.ink),
          ),
          const Spacer(),
          Text(item.title,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: EzColors.ink)),
          const SizedBox(height: 2),
          Text(item.subtitle,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 11, color: EzColors.muted)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: EzColors.cream2,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              item.tag.toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: EzColors.inkSoft,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Ambient SVG-style house painter
class _AmbientPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF141414).withValues(alpha: 0.07)
      ..style = PaintingStyle.fill;

    // Simple house shapes
    final houses = [
      [0.06, 0.72, 0.22, 0.90, 0.08, 0.70],
      [0.25, 0.76, 0.44, 0.90, 0.17, 0.72],
      [0.46, 0.74, 0.65, 0.90, 0.37, 0.70],
      [0.66, 0.76, 0.82, 0.90, 0.60, 0.72],
      [0.83, 0.73, 0.99, 0.90, 0.76, 0.70],
    ];

    for (final h in houses) {
      final path = Path();
      final left = h[0] * size.width;
      final right = h[1] * size.width;
      final bottom = h[2] * size.height;
      final peakX = (left + right) / 2;
      final peakY = h[3] * size.height;
      path.moveTo(left, bottom);
      path.lineTo(peakX, peakY);
      path.lineTo(right, bottom);
      path.close();
      canvas.drawPath(path, paint);

      // Body
      final bodyPaint = Paint()
        ..color = const Color(0xFF141414).withValues(alpha: 0.05)
        ..style = PaintingStyle.fill;
      canvas.drawRect(
        Rect.fromLTRB(left + 2, bottom, right - 2, size.height),
        bodyPaint,
      );
    }

    // Sun circle
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.22),
      20,
      Paint()..color = const Color(0xFFFCD24A).withValues(alpha: 0.55),
    );
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.22),
      13,
      Paint()..color = const Color(0xFFFCD24A).withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

class _TypingText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Duration typingSpeed;

  const _TypingText({
    required this.text,
    required this.style,
    this.typingSpeed = const Duration(milliseconds: 75),
  });

  @override
  State<_TypingText> createState() => _TypingTextState();
}

class _TypingTextState extends State<_TypingText>
    with SingleTickerProviderStateMixin {
  String _displayedText = '';
  int _charIndex = 0;
  Timer? _timer;
  late final AnimationController _cursorController;
  bool _showCursor = true;

  @override
  void initState() {
    super.initState();
    _cursorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            _showCursor = !_showCursor;
          });
          _cursorController.forward(from: 0);
        }
      });
    _cursorController.forward();
    _startTyping();
  }

  void _startTyping() {
    // Start typing after a short delay so the page transition finishes
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _timer = Timer.periodic(widget.typingSpeed, (timer) {
        if (_charIndex < widget.text.length) {
          setState(() {
            _displayedText += widget.text[_charIndex];
            _charIndex++;
          });
        } else {
          _timer?.cancel();
          // Hide cursor after a few seconds of idle
          Future.delayed(const Duration(seconds: 4), () {
            if (mounted) {
              _cursorController.stop();
              setState(() {
                _showCursor = false;
              });
            }
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cursorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(text: _displayedText, style: widget.style),
          TextSpan(
            text: _showCursor ? '|' : '',
            style: widget.style.copyWith(
              color: EzColors.yellowDeep,
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
      ),
    );
  }
}
