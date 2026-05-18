import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/ez_colors.dart';
import '../../core/models/agent_response.dart';
import '../confirm/confirm_screen.dart';

class ResultsScreen extends StatelessWidget {
  final AgentRunOut agentResult;

  const ResultsScreen({super.key, required this.agentResult});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    final provider = agentResult.selectedProvider;
    final booking = agentResult.booking;
    final reasoning = agentResult.reasoning ?? agentResult.formattedMessage;
    final suggestions = agentResult.suggestions ?? [];
    // Determine if this is an inquiry response (no provider booked, but has info)
    final isInquiry = provider == null && agentResult.formattedMessage != null;

    // Build a human-readable slot string from booking
    String slotText = 'Confirmed';
    if (booking != null) {
      try {
        final dt = DateTime.parse(booking.scheduledAt).toLocal();
        final months = [
          'Jan','Feb','Mar','Apr','May','Jun',
          'Jul','Aug','Sep','Oct','Nov','Dec'
        ];
        final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
        final ampm = dt.hour < 12 ? 'AM' : 'PM';
        final min = dt.minute.toString().padLeft(2, '0');
        slotText = '${months[dt.month - 1]} ${dt.day}, $hour:$min $ampm';
      } catch (_) {
        slotText = booking.scheduledAt;
      }
    }

    final serviceLabel =
        provider?.category.replaceAll('_', ' ').split(' ').map((w) {
              return w.isNotEmpty
                  ? '${w[0].toUpperCase()}${w.substring(1)}'
                  : w;
            }).join(' ') ??
            'Service';

    final initials = provider != null
        ? provider.name.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join()
        : 'EZ';

    return Scaffold(
      backgroundColor: EzColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  _CircleBtn(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_rounded,
                        size: 18, color: EzColors.ink),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(isInquiry ? 'EZ Info' : 'AI Best Match',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: EzColors.ink)),
                        Text(isInquiry
                            ? serviceLabel
                            : '$serviceLabel · ${provider?.area ?? "Your area"}',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 10.5,
                                color: EzColors.muted,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  _CircleBtn(
                    child: const Icon(Icons.refresh_rounded,
                        size: 18, color: EzColors.ink),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms),

            // ── AI insight bar ──
            if (reasoning != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: EzColors.yellowGlow,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: EzColors.yellow),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: EzColors.ink,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: const Icon(Icons.auto_awesome_rounded,
                            size: 13, color: EzColors.yellow),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          reasoning,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: EzColors.ink,
                              height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

            // ── Provider card ──
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  if (provider != null)
                    ProviderCard(
                      rank: 1,
                      name: provider.name,
                      shop: '${serviceLabel} Provider',
                      rating: provider.rating ?? 4.5,
                      reviews: null,
                      distance: provider.distanceKm != null
                          ? '${provider.distanceKm!.toStringAsFixed(1)} km'
                          : (provider.area ?? ''),
                      price: '',
                      slot: slotText,
                      reasons: suggestions.take(3).toList().isNotEmpty
                          ? suggestions.take(3).toList()
                          : ['AI Matched', 'Verified', 'Available'],
                      accent: const Color(0xFFFCD24A),
                      isAiPick: true,
                      onBook: () => Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (_, a, __) => ConfirmScreen(
                            provider: provider,
                            booking: booking,
                          ),
                          transitionsBuilder: (_, a, __, child) =>
                              FadeTransition(opacity: a, child: child),
                          transitionDuration: const Duration(milliseconds: 400),
                        ),
                      ),
                    ).animate().fadeIn(delay: 150.ms, duration: 400.ms).slideY(
                        begin: 0.2,
                        end: 0,
                        delay: 150.ms,
                        duration: 400.ms),

                  if (provider == null && isInquiry)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Info header pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: EzColors.ink,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.info_outline_rounded,
                                    size: 12, color: EzColors.yellow),
                                const SizedBox(width: 5),
                                Text('EZ Info',
                                    style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: EzColors.yellow,
                                        letterSpacing: 0.5)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Agent's formatted message
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: EzColors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: EzColors.yellow),
                              boxShadow: [
                                BoxShadow(
                                    color: EzColors.yellow.withOpacity(0.15),
                                    blurRadius: 20,
                                    offset: const Offset(0, 6)),
                              ],
                            ),
                            child: Text(
                              agentResult.formattedMessage ?? reasoning ?? '',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: EzColors.ink,
                                  height: 1.55),
                            ),
                          ),

                          if (suggestions.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: suggestions
                                  .map((s) => GestureDetector(
                                        onTap: () => Navigator.pop(context),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 7),
                                          decoration: BoxDecoration(
                                            color: EzColors.white,
                                            borderRadius:
                                                BorderRadius.circular(999),
                                            border: Border.all(
                                                color: EzColors.border),
                                          ),
                                          child: Text(s,
                                              style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: EzColors.ink)),
                                        ),
                                      ))
                                  .toList(),
                            ),
                          ],
                        ],
                      ),
                    ).animate().fadeIn(delay: 150.ms, duration: 400.ms).slideY(
                        begin: 0.2,
                        end: 0,
                        delay: 150.ms,
                        duration: 400.ms),

                  if (provider == null && !isInquiry)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          const Icon(Icons.search_off_rounded,
                              size: 48, color: EzColors.muted2),
                          const SizedBox(height: 12),
                          Text('No provider found',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: EzColors.ink)),
                          const SizedBox(height: 6),
                          Text(
                              reasoning ??
                                  'EZ could not find a matching provider. Try again.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13, color: EzColors.muted)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Provider Card ───────────────────────────────────────────

class ProviderCard extends StatefulWidget {
  final int rank;
  final String name;
  final String shop;
  final double rating;
  final int? reviews;
  final String distance;
  final String price;
  final String slot;
  final List<String> reasons;
  final Color accent;
  final bool isAiPick;
  final VoidCallback? onBook;

  const ProviderCard({
    super.key,
    required this.rank,
    required this.name,
    required this.shop,
    required this.rating,
    this.reviews,
    required this.distance,
    required this.price,
    required this.slot,
    required this.reasons,
    required this.accent,
    this.isAiPick = false,
    this.onBook,
  });

  @override
  State<ProviderCard> createState() => _ProviderCardState();
}

class _ProviderCardState extends State<ProviderCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double> _press;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _press = Tween(begin: 1.0, end: 0.98)
        .animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  String get _initials =>
      widget.name.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _pressCtrl.forward(),
      onTapUp: (_) => _pressCtrl.reverse(),
      onTapCancel: () => _pressCtrl.reverse(),
      child: ScaleTransition(
        scale: _press,
        child: Container(
          decoration: BoxDecoration(
            color: EzColors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: widget.isAiPick ? EzColors.yellow : EzColors.border,
              width: widget.isAiPick ? 1.5 : 1.0,
            ),
            boxShadow: widget.isAiPick
                ? [
                    BoxShadow(
                        color: EzColors.yellow.withOpacity(0.18),
                        blurRadius: 0,
                        spreadRadius: 4),
                    BoxShadow(
                        color: EzColors.yellowDeep.withOpacity(0.18),
                        blurRadius: 40,
                        offset: const Offset(0, 18)),
                  ]
                : [
                    BoxShadow(
                        color: EzColors.ink.withOpacity(0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2)),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Column(
              children: [
                if (widget.isAiPick)
                  Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 5, 12, 5),
                      decoration: const BoxDecoration(
                        color: EzColors.ink,
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(14),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.auto_awesome_rounded,
                              size: 10, color: EzColors.yellow),
                          const SizedBox(width: 4),
                          Text('AI PICK',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: EzColors.yellow,
                                  letterSpacing: 0.6)),
                        ],
                      ),
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Top row ──
                      Row(
                        children: [
                          // Avatar
                          Container(
                            width: widget.isAiPick ? 62 : 52,
                            height: widget.isAiPick ? 62 : 52,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [widget.accent, const Color(0xFFFFE988)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: EzColors.borderSoft, width: 1),
                            ),
                            child: Center(
                              child: Text(
                                _initials,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: widget.isAiPick ? 22 : 18,
                                  fontWeight: FontWeight.w800,
                                  color: EzColors.ink,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(widget.name,
                                          style: GoogleFonts.plusJakartaSans(
                                              fontSize:
                                                  widget.isAiPick ? 15 : 14,
                                              fontWeight: FontWeight.w800,
                                              color: EzColors.ink)),
                                    ),
                                    const SizedBox(width: 5),
                                    const Icon(Icons.verified_rounded,
                                        size: 14, color: EzColors.info),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                    '${widget.shop}${widget.distance.isNotEmpty ? ' · ${widget.distance}' : ''}',
                                    style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11.5,
                                        color: EzColors.muted,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 5),
                                Row(
                                  children: [
                                    const Icon(Icons.star_rounded,
                                        size: 13,
                                        color: EzColors.yellowDeep),
                                    const SizedBox(width: 3),
                                    Text(widget.rating.toStringAsFixed(1),
                                        style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w800,
                                            color: EzColors.ink)),
                                    if (widget.reviews != null) ...[
                                      const SizedBox(width: 3),
                                      Text('(${widget.reviews})',
                                          style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11,
                                              color: EzColors.muted)),
                                    ],
                                    if (widget.price.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                          width: 3,
                                          height: 3,
                                          decoration: BoxDecoration(
                                              color: EzColors.muted2,
                                              shape: BoxShape.circle)),
                                      const SizedBox(width: 6),
                                      Text(widget.price,
                                          style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: EzColors.inkSoft)),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Availability pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: EzColors.successSoft,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                              color: const Color(0xFFBBF7D0), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: EzColors.success,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text('Booked: ${widget.slot}',
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF166534))),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Reasoning pills
                      Container(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                        decoration: BoxDecoration(
                          color: widget.isAiPick
                              ? EzColors.yellowGlow
                              : EzColors.cream,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: widget.isAiPick
                                ? EzColors.yellow
                                : EzColors.border,
                          ),
                        ),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.auto_awesome_rounded,
                                    size: 9, color: EzColors.yellowDeep),
                                const SizedBox(width: 3),
                                Text('Why this one',
                                    style: GoogleFonts.plusJakartaSans(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        color: EzColors.inkSoft,
                                        letterSpacing: 0.4)),
                              ],
                            ),
                            ...widget.reasons.map(
                              (r) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: EzColors.white,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                      color: EzColors.borderSoft),
                                ),
                                child: Text(r,
                                    style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: EzColors.ink)),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // CTAs
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: GestureDetector(
                              onTap: widget.onBook,
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: widget.isAiPick
                                      ? EzColors.ink
                                      : EzColors.cream2,
                                  borderRadius: BorderRadius.circular(999),
                                  border: widget.isAiPick
                                      ? null
                                      : Border.all(color: EzColors.border),
                                  boxShadow: widget.isAiPick
                                      ? [
                                          BoxShadow(
                                            color:
                                                EzColors.ink.withOpacity(0.18),
                                            blurRadius: 16,
                                            offset: const Offset(0, 6),
                                          )
                                        ]
                                      : [],
                                ),
                                child: Text(
                                  'Confirm Booking',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: widget.isAiPick
                                        ? EzColors.white
                                        : EzColors.ink,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: EzColors.white,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: EzColors.border),
                              ),
                              child: Text(
                                'Profile',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: EzColors.ink),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────

class _CircleBtn extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _CircleBtn({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: EzColors.white,
          shape: BoxShape.circle,
          border: Border.all(color: EzColors.border),
          boxShadow: [
            BoxShadow(
                color: EzColors.ink.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }
}
