import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/ez_colors.dart';
import '../../core/models/agent_response.dart';
import '../home/home_screen.dart';

class ConfirmScreen extends StatefulWidget {
  final ProviderBrief provider;
  final BookingBrief? booking;

  const ConfirmScreen({
    super.key,
    required this.provider,
    this.booking,
  });

  @override
  State<ConfirmScreen> createState() => _ConfirmScreenState();
}

class _ConfirmScreenState extends State<ConfirmScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _checkCtrl;

  @override
  void initState() {
    super.initState();
    _checkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _checkCtrl.dispose();
    super.dispose();
  }

  String get _slotText {
    if (widget.booking == null) return 'Scheduled';
    try {
      final dt = DateTime.parse(widget.booking!.scheduledAt).toLocal();
      final months = [
        'Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'
      ];
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final ampm = dt.hour < 12 ? 'AM' : 'PM';
      final min = dt.minute.toString().padLeft(2, '0');
      return '${months[dt.month - 1]} ${dt.day}, $hour:$min $ampm';
    } catch (_) {
      return widget.booking!.scheduledAt;
    }
  }

  String get _initials =>
      widget.provider.name.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join();

  String get _categoryLabel => widget.provider.category
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : w)
      .join(' ');

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: EzColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                children: [
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                      (r) => false,
                    ),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: EzColors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: EzColors.border),
                      ),
                      child: const Icon(Icons.close_rounded,
                          size: 16, color: EzColors.ink),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),

                    // ── Confirmation circle ──
                    AnimatedBuilder(
                      animation: _checkCtrl,
                      builder: (_, __) {
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            Transform.scale(
                              scale: 1.0 + _checkCtrl.value * 0.06,
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(colors: [
                                    EzColors.yellow.withOpacity(0.5),
                                    Colors.transparent,
                                  ]),
                                ),
                              ),
                            ),
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: EzColors.yellow.withOpacity(0.4),
                                    width: 1.5),
                              ),
                            ),
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [EzColors.yellow, Color(0xFFFFE988)],
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: EzColors.yellowDeep.withOpacity(0.3),
                                    blurRadius: 28,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.check_rounded,
                                  size: 38, color: EzColors.ink),
                            ),
                          ],
                        );
                      },
                    )
                        .animate()
                        .scale(
                            begin: const Offset(0.5, 0.5),
                            end: const Offset(1.0, 1.0),
                            duration: 600.ms,
                            curve: Curves.elasticOut)
                        .fadeIn(duration: 400.ms),

                    const SizedBox(height: 18),

                    Text('Booking Confirmed!',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: EzColors.ink,
                              letterSpacing: -0.5,
                            ))
                        .animate()
                        .fadeIn(delay: 200.ms, duration: 400.ms)
                        .slideY(begin: 0.2, end: 0, delay: 200.ms, duration: 400.ms),

                    const SizedBox(height: 8),

                    Text(
                            widget.booking != null
                                ? 'Your booking is confirmed for $_slotText.\nEZ Agent has got you covered.'
                                : 'Your request has been processed.\nEZ Agent has got you covered.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              color: EzColors.inkSoft,
                              fontWeight: FontWeight.w500,
                              height: 1.5,
                            ))
                        .animate()
                        .fadeIn(delay: 300.ms, duration: 400.ms),

                    const SizedBox(height: 24),

                    // ── Provider card ──
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: EzColors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                            color: EzColors.yellow, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                              color: EzColors.yellow.withOpacity(0.15),
                              blurRadius: 0,
                              spreadRadius: 4),
                          BoxShadow(
                              color: EzColors.yellowDeep.withOpacity(0.15),
                              blurRadius: 40,
                              offset: const Offset(0, 16)),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFFFCD24A),
                                      Color(0xFFFFE988)
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Center(
                                  child: Text(_initials,
                                      style: GoogleFonts.plusJakartaSans(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          color: EzColors.ink)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(widget.provider.name,
                                              style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w800,
                                                  color: EzColors.ink)),
                                        ),
                                        const Icon(Icons.verified_rounded,
                                            size: 15, color: EzColors.info),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                        '$_categoryLabel · ${widget.provider.area ?? "Your area"}',
                                        style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            color: EzColors.muted,
                                            fontWeight: FontWeight.w600)),
                                    if (widget.provider.rating != null) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.star_rounded,
                                              size: 12,
                                              color: EzColors.yellowDeep),
                                          const SizedBox(width: 3),
                                          Text(
                                              widget.provider.rating!
                                                  .toStringAsFixed(1),
                                              style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: EzColors.ink)),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),
                          Divider(color: EzColors.borderSoft),
                          const SizedBox(height: 12),

                          // Booking details
                          _DetailRow(
                            icon: Icons.calendar_today_rounded,
                            label: 'Scheduled',
                            value: _slotText,
                          ),
                          const SizedBox(height: 8),
                          _DetailRow(
                            icon: Icons.confirmation_number_outlined,
                            label: 'Booking ID',
                            value: widget.booking?.id.substring(0, 8).toUpperCase() ??
                                'PENDING',
                          ),
                          const SizedBox(height: 8),
                          _DetailRow(
                            icon: Icons.info_outline_rounded,
                            label: 'Status',
                            value: widget.booking?.status.toUpperCase() ??
                                'CONFIRMED',
                            valueColor: EzColors.success,
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 400.ms, duration: 400.ms).slideY(
                        begin: 0.2, end: 0, delay: 400.ms, duration: 400.ms),

                    const SizedBox(height: 16),

                    // EZ notification note
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: EzColors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: EzColors.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: EzColors.yellowGlow,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: EzColors.yellow),
                            ),
                            child: const Icon(Icons.notifications_outlined,
                                size: 18, color: EzColors.ink),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Reminder set',
                                    style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: EzColors.ink)),
                                Text(
                                    "EZ Agent will send a reminder before $_slotText.",
                                    style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        color: EzColors.muted,
                                        fontWeight: FontWeight.w500,
                                        height: 1.4)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 500.ms, duration: 300.ms),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // ── Bottom CTAs ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                      (r) => false,
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                        color: EzColors.ink,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: EzColors.ink.withOpacity(0.2),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Go to Home',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: EzColors.white,
                              )),
                          const SizedBox(width: 8),
                          const Icon(Icons.home_rounded,
                              size: 18, color: EzColors.yellow),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: 600.ms, duration: 300.ms),

                  const SizedBox(height: 10),

                  GestureDetector(
                    onTap: () {
                      // Track provider — placeholder for future GPS tracking
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Live tracking coming soon!',
                              style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w600)),
                          backgroundColor: EzColors.ink,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: EzColors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: EzColors.border, width: 1.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.my_location_rounded,
                              size: 15, color: EzColors.ink),
                          const SizedBox(width: 7),
                          Text('Track Provider',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: EzColors.ink)),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: 650.ms, duration: 300.ms),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: EzColors.muted),
        const SizedBox(width: 7),
        Text(label,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: EzColors.muted,
                fontWeight: FontWeight.w600)),
        const Spacer(),
        Text(value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: valueColor ?? EzColors.ink,
            )),
      ],
    );
  }
}
