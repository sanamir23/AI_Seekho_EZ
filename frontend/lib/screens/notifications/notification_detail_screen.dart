import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/ez_colors.dart';
import 'notification_model.dart';

class NotificationDetailScreen extends StatefulWidget {
  final NotifItem notif;
  const NotificationDetailScreen({super.key, required this.notif});

  @override
  State<NotificationDetailScreen> createState() =>
      _NotificationDetailScreenState();
}

class _NotificationDetailScreenState extends State<NotificationDetailScreen> {
  // Rating state
  int _rating = 0;
  final _reviewController = TextEditingController();
  bool _submitted = false;

  // Reschedule state
  bool _rescheduled = false;
  bool _declined = false;

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
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
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeroCard(),
                  const SizedBox(height: 20),
                  _buildDetailBody(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFE988), Color(0xFFFBF8F1)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
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
                          offset: const Offset(0, 2))
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.arrow_back_ios_new_rounded,
                        size: 15, color: EzColors.ink),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                _headerTitle(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: EzColors.ink,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  String _headerTitle() {
    switch (widget.notif.type) {
      case NotifType.cancellation:
        return 'Cancellation Notice';
      case NotifType.arrival:
        return 'Provider Tracking';
      case NotifType.appointment:
        return 'Booking Details';
      case NotifType.rating:
        return 'Rate Your Service';
      case NotifType.promo:
        return 'Special Offer';
      case NotifType.reminder:
        return 'Service Reminder';
    }
  }

  // ── Hero card ─────────────────────────────────────────────────
  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: EzColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.notif.type == NotifType.cancellation
              ? const Color(0xFFFFCDD2)
              : EzColors.yellowSoft,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
              color: EzColors.ink.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: widget.notif.iconBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(widget.notif.icon, size: 24, color: widget.notif.iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.notif.title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: EzColors.ink,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.notif.body,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: EzColors.inkSoft,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded,
                        size: 12, color: EzColors.muted),
                    const SizedBox(width: 4),
                    Text(widget.notif.time,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5, color: EzColors.muted, fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms, duration: 350.ms).slideY(begin: 0.1, end: 0);
  }

  // ── Detail body per type ──────────────────────────────────────
  Widget _buildDetailBody(BuildContext context) {
    switch (widget.notif.type) {
      case NotifType.cancellation:
        return _buildCancellationDetail(context);
      case NotifType.arrival:
        return _buildArrivalDetail(context);
      case NotifType.appointment:
        return _buildAppointmentDetail(context);
      case NotifType.rating:
        return _buildRatingDetail(context);
      case NotifType.promo:
        return _buildPromoDetail(context);
      case NotifType.reminder:
        return _buildReminderDetail(context);
    }
  }

  // ── CANCELLATION ──────────────────────────────────────────────
  Widget _buildCancellationDetail(BuildContext context) {
    if (_rescheduled) return _successBanner('Reschedule Confirmed!',
        'Your appointment has been rescheduled for tomorrow at 2:00 PM.', Icons.check_circle_rounded);
    if (_declined) return _successBanner('Request Declined',
        'We\'ll help you find another provider right away.', Icons.search_rounded, isWarning: true);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Proposed New Time'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardDecor(),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: EzColors.yellow, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.event_rounded, size: 22, color: EzColors.ink),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tomorrow', style: GoogleFonts.plusJakartaSans(
                      fontSize: 13, color: EzColors.muted, fontWeight: FontWeight.w500)),
                  Text('2:00 PM', style: GoogleFonts.plusJakartaSans(
                      fontSize: 22, fontWeight: FontWeight.w800, color: EzColors.ink,
                      letterSpacing: -0.5)),
                  Text('Wednesday, 21 May 2026', style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, color: EzColors.inkSoft)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _sectionLabel('Provider'),
        const SizedBox(height: 10),
        _providerRow('Hassan', 'Deep Cleaning Specialist', '4.8'),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _outlineBtn('Decline', Icons.close_rounded, () {
                setState(() => _declined = true);
              }, danger: true),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: _filledBtn('Accept Reschedule', Icons.check_rounded, () {
                setState(() => _rescheduled = true);
              }),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(delay: 200.ms, duration: 350.ms);
  }

  // ── ARRIVAL ───────────────────────────────────────────────────
  Widget _buildArrivalDetail(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Live ETA'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: _cardDecor(bg: EzColors.yellow),
          child: Center(
            child: Column(
              children: [
                Text('~10 min', style: GoogleFonts.plusJakartaSans(
                    fontSize: 40, fontWeight: FontWeight.w800,
                    color: EzColors.ink, letterSpacing: -1.5)),
                Text('away from your location', style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, color: EzColors.inkSoft)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        _sectionLabel('Provider Details'),
        const SizedBox(height: 10),
        _providerRow('Ali', 'AC Technician', '4.9'),
        const SizedBox(height: 14),
        _sectionLabel('Service Address'),
        const SizedBox(height: 10),
        _infoRow(Icons.location_on_rounded, 'House 42, Street 3, G-13, Islamabad'),
        const SizedBox(height: 24),
        _filledBtn('Call Provider', Icons.phone_rounded, () {
          ScaffoldMessenger.of(context).showSnackBar(_snack('Calling Ali...'));
        }),
      ],
    ).animate().fadeIn(delay: 200.ms, duration: 350.ms);
  }

  // ── APPOINTMENT ───────────────────────────────────────────────
  Widget _buildAppointmentDetail(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Booking Summary'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardDecor(),
          child: Column(
            children: [
              _detailRow('Service', 'Deep Cleaning'),
              _detailRow('Date', 'Today, 20 May 2026'),
              _detailRow('Time', '3:00 PM'),
              _detailRow('Duration', '3 hours'),
              _detailRow('Status', 'Confirmed ✓', valueColor: EzColors.success),
              _detailRow('Price', '₨ 3,500'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _sectionLabel('Provider'),
        const SizedBox(height: 10),
        _providerRow('Hassan', 'Deep Cleaning Specialist', '4.8'),
        const SizedBox(height: 24),
        _outlineBtn('Cancel Booking', Icons.cancel_outlined, () {
          ScaffoldMessenger.of(context)
              .showSnackBar(_snack('Cancellation request sent.'));
        }, danger: true),
      ],
    ).animate().fadeIn(delay: 200.ms, duration: 350.ms);
  }

  // ── RATING ────────────────────────────────────────────────────
  Widget _buildRatingDetail(BuildContext context) {
    if (_submitted) return _successBanner('Thank you!',
        'Your review has been submitted and will help other customers.', Icons.favorite_rounded);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Recent Service'),
        const SizedBox(height: 10),
        _providerRow('Usman', 'Plumber', '4.7'),
        const SizedBox(height: 20),
        _sectionLabel('Your Rating'),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) => GestureDetector(
            onTap: () => setState(() => _rating = i + 1),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Icon(
                i < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 38,
                color: i < _rating ? EzColors.yellowDeep : EzColors.muted2,
              ).animate(target: i < _rating ? 1 : 0)
                .scale(begin: const Offset(1, 1), end: const Offset(1.25, 1.25),
                    duration: 150.ms),
            ),
          )),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            _ratingLabel(),
            style: GoogleFonts.plusJakartaSans(
                fontSize: 13, color: EzColors.muted, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(height: 20),
        _sectionLabel('Write a Review (optional)'),
        const SizedBox(height: 10),
        Container(
          decoration: _cardDecor(),
          child: TextField(
            controller: _reviewController,
            maxLines: 4,
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: EzColors.ink),
            decoration: InputDecoration(
              hintText: 'Share your experience...',
              hintStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 13, color: EzColors.muted2),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
        const SizedBox(height: 24),
        _filledBtn('Submit Review', Icons.send_rounded, () {
          if (_rating == 0) {
            ScaffoldMessenger.of(context)
                .showSnackBar(_snack('Please select a star rating first.'));
            return;
          }
          setState(() => _submitted = true);
        }),
      ],
    ).animate().fadeIn(delay: 200.ms, duration: 350.ms);
  }

  String _ratingLabel() {
    switch (_rating) {
      case 1: return 'Poor';
      case 2: return 'Fair';
      case 3: return 'Good';
      case 4: return 'Very Good';
      case 5: return 'Excellent!';
      default: return 'Tap a star to rate';
    }
  }

  // ── PROMO ─────────────────────────────────────────────────────
  Widget _buildPromoDetail(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: EzColors.yellow,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Text('YOUR CODE', style: GoogleFonts.plusJakartaSans(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: EzColors.inkSoft, letterSpacing: 1.5)),
              const SizedBox(height: 8),
              Text('EZ20', style: GoogleFonts.plusJakartaSans(
                  fontSize: 42, fontWeight: FontWeight.w900,
                  color: EzColors.ink, letterSpacing: 4)),
              const SizedBox(height: 4),
              Text('20% off any home service', style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, color: EzColors.inkSoft)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _sectionLabel('Terms'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardDecor(),
          child: Column(
            children: [
              _detailRow('Valid Until', 'Friday, 23 May 2026'),
              _detailRow('Min. Order', '₨ 1,000'),
              _detailRow('Max Discount', '₨ 500'),
              _detailRow('Applicable On', 'All services'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _filledBtn('Copy Code', Icons.copy_rounded, () {
          Clipboard.setData(const ClipboardData(text: 'EZ20'));
          ScaffoldMessenger.of(context)
              .showSnackBar(_snack('Code EZ20 copied to clipboard!'));
        }),
      ],
    ).animate().fadeIn(delay: 200.ms, duration: 350.ms);
  }

  // ── REMINDER ─────────────────────────────────────────────────
  Widget _buildReminderDetail(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Last Serviced'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardDecor(),
          child: Column(
            children: [
              _detailRow('Service', 'AC Maintenance'),
              _detailRow('Last Done', 'November 2025'),
              _detailRow('Recommended', 'Every 6 months'),
              _detailRow('Status', '6 months overdue', valueColor: const Color(0xFFD93025)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _filledBtn('Book AC Service Now', Icons.ac_unit_rounded, () {
          Navigator.pop(context);
          ScaffoldMessenger.of(context)
              .showSnackBar(_snack('Opening service booking...'));
        }),
      ],
    ).animate().fadeIn(delay: 200.ms, duration: 350.ms);
  }

  // ── Shared helpers ────────────────────────────────────────────
  Widget _sectionLabel(String text) => Text(text,
      style: GoogleFonts.plusJakartaSans(
          fontSize: 12, fontWeight: FontWeight.w700,
          color: EzColors.muted, letterSpacing: 0.8));

  BoxDecoration _cardDecor({Color? bg}) => BoxDecoration(
        color: bg ?? EzColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: EzColors.border),
        boxShadow: [
          BoxShadow(color: EzColors.ink.withValues(alpha: 0.04),
              blurRadius: 8, offset: const Offset(0, 3))
        ],
      );

  Widget _providerRow(String name, String role, String rating) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: _cardDecor(),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFFFCD24A), Color(0xFFE8B617)]),
                shape: BoxShape.circle,
                border: Border.all(color: EzColors.white, width: 2),
              ),
              child: Center(
                child: Text(name[0],
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 18, fontWeight: FontWeight.w800,
                        color: EzColors.ink)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: GoogleFonts.plusJakartaSans(
                      fontSize: 14, fontWeight: FontWeight.w700, color: EzColors.ink)),
                  Text(role, style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, color: EzColors.muted)),
                ],
              ),
            ),
            Row(
              children: [
                const Icon(Icons.star_rounded, size: 14, color: EzColors.yellowDeep),
                const SizedBox(width: 3),
                Text(rating, style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, fontWeight: FontWeight.w700, color: EzColors.ink)),
              ],
            ),
          ],
        ),
      );

  Widget _detailRow(String label, String value, {Color? valueColor}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Text(label, style: GoogleFonts.plusJakartaSans(
                fontSize: 13, color: EzColors.muted)),
            const Spacer(),
            Text(value, style: GoogleFonts.plusJakartaSans(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: valueColor ?? EzColors.ink)),
          ],
        ),
      );

  Widget _infoRow(IconData icon, String text) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: _cardDecor(),
        child: Row(
          children: [
            Icon(icon, size: 18, color: EzColors.inkSoft),
            const SizedBox(width: 10),
            Expanded(child: Text(text,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, color: EzColors.ink))),
          ],
        ),
      );

  Widget _filledBtn(String label, IconData icon, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: EzColors.ink,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: EzColors.ink.withValues(alpha: 0.2),
                  blurRadius: 12, offset: const Offset(0, 4))
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: EzColors.yellow),
              const SizedBox(width: 8),
              Text(label, style: GoogleFonts.plusJakartaSans(
                  fontSize: 14, fontWeight: FontWeight.w700, color: EzColors.white)),
            ],
          ),
        ),
      );

  Widget _outlineBtn(String label, IconData icon, VoidCallback onTap,
      {bool danger = false}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: EzColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: danger ? const Color(0xFFFFCDD2) : EzColors.border,
                width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16,
                  color: danger ? const Color(0xFFD93025) : EzColors.inkSoft),
              const SizedBox(width: 8),
              Text(label, style: GoogleFonts.plusJakartaSans(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: danger ? const Color(0xFFD93025) : EzColors.inkSoft)),
            ],
          ),
        ),
      );

  Widget _successBanner(String title, String subtitle, IconData icon,
      {bool isWarning = false}) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isWarning ? EzColors.cream2 : EzColors.successSoft,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isWarning ? EzColors.border : EzColors.success.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 48,
                color: isWarning ? EzColors.inkSoft : EzColors.success),
            const SizedBox(height: 12),
            Text(title, style: GoogleFonts.plusJakartaSans(
                fontSize: 18, fontWeight: FontWeight.w800, color: EzColors.ink)),
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, color: EzColors.inkSoft, height: 1.5)),
          ],
        ),
      ).animate().scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1),
          duration: 300.ms, curve: Curves.easeOutBack)
          .fadeIn(duration: 250.ms);

  SnackBar _snack(String msg) => SnackBar(
    content: Text(msg, style: GoogleFonts.plusJakartaSans(
        fontSize: 13, color: EzColors.ink)),
    backgroundColor: EzColors.yellow,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    duration: const Duration(seconds: 2),
  );
}
