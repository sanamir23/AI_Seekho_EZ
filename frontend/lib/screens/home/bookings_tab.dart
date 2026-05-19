import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/ez_colors.dart';
import '../../core/models/booking.dart';
import '../../core/services/api_service.dart';

enum _Filter { all, active, completed, cancelled }

class BookingsTab extends StatefulWidget {
  const BookingsTab({super.key});

  @override
  State<BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends State<BookingsTab> {
  List<BookingOut> _bookings = [];
  bool _loading = false;
  final Set<String> _cancellingIds = {};
  _Filter _filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final bookings = await ApiService.instance.listBookings();
      if (mounted) setState(() => _bookings = bookings);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<BookingOut> get _filtered {
    switch (_filter) {
      case _Filter.active:
        return _bookings
            .where((b) => b.status == 'confirmed' || b.status == 'pending')
            .toList();
      case _Filter.completed:
        return _bookings.where((b) => b.status == 'completed').toList();
      case _Filter.cancelled:
        return _bookings.where((b) => b.status == 'cancelled').toList();
      case _Filter.all:
        return _bookings;
    }
  }

  Future<void> _cancelBooking(String bookingId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Cancel Booking?',
          style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: Text(
          'Are you sure you want to cancel this booking?',
          style: GoogleFonts.plusJakartaSans(
              fontSize: 13, color: EzColors.inkSoft),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Keep it',
                style: GoogleFonts.plusJakartaSans(color: EzColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Yes, cancel',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFFDC2626),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _cancellingIds.add(bookingId));
    try {
      await ApiService.instance.cancelBooking(bookingId);
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to cancel booking'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _cancellingIds.remove(bookingId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──────────────────────────────────────────────────
        _Header(
          count: _bookings.length,
          onRefresh: _load,
        ),

        // ── Filter chips ─────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _Filter.values.map((f) {
                final active = _filter == f;
                final label = {
                  _Filter.all: 'All',
                  _Filter.active: 'Active',
                  _Filter.completed: 'Completed',
                  _Filter.cancelled: 'Cancelled',
                }[f]!;
                final count = {
                  _Filter.all: _bookings.length,
                  _Filter.active: _bookings
                      .where((b) =>
                          b.status == 'confirmed' || b.status == 'pending')
                      .length,
                  _Filter.completed: _bookings
                      .where((b) => b.status == 'completed')
                      .length,
                  _Filter.cancelled: _bookings
                      .where((b) => b.status == 'cancelled')
                      .length,
                }[f]!;
                return GestureDetector(
                  onTap: () => setState(() => _filter = f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: active ? EzColors.ink : EzColors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: active ? EzColors.ink : EzColors.border,
                      ),
                      boxShadow: active
                          ? [
                              BoxShadow(
                                color: EzColors.ink.withValues(alpha: 0.12),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : [],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color:
                                active ? EzColors.yellow : EzColors.inkSoft,
                          ),
                        ),
                        if (count > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: active
                                  ? EzColors.yellow.withValues(alpha: 0.25)
                                  : EzColors.cream2,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '$count',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: active
                                    ? EzColors.yellow
                                    : EzColors.muted,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // ── List ─────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: EzColors.yellowDeep,
                    strokeWidth: 2.5,
                  ),
                )
              : filtered.isEmpty
                  ? _EmptyState(filter: _filter)
                  : RefreshIndicator(
                      color: EzColors.yellowDeep,
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (_, i) => _BookingCard(
                          booking: filtered[i],
                          isCancelling:
                              _cancellingIds.contains(filtered[i].id),
                          onCancel: () => _cancelBooking(filtered[i].id),
                        )
                            .animate()
                            .fadeIn(
                                delay: (i * 55).ms, duration: 280.ms)
                            .slideY(
                                begin: 0.08,
                                end: 0,
                                delay: (i * 55).ms,
                                duration: 280.ms,
                                curve: Curves.easeOut),
                      ),
                    ),
        ),
      ],
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final int count;
  final VoidCallback onRefresh;

  const _Header({required this.count, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
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
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My Bookings',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: EzColors.ink,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    count == 0
                        ? 'No bookings yet'
                        : '$count booking${count == 1 ? '' : 's'} total',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: EzColors.inkSoft,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              GestureDetector(
                onTap: onRefresh,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: EzColors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: EzColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: EzColors.ink.withValues(alpha: 0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: const Icon(Icons.refresh_rounded,
                      size: 18, color: EzColors.ink),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final _Filter filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final isFiltered = filter != _Filter.all;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: EzColors.yellow,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(Icons.calendar_today_rounded,
                size: 34, color: EzColors.ink),
          ),
          const SizedBox(height: 18),
          Text(
            isFiltered
                ? 'No ${filter.name} bookings'
                : 'No bookings yet',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: EzColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isFiltered
                ? 'Try a different filter'
                : 'Your booked services will appear here',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 13, color: EzColors.muted),
          ),
        ],
      ),
    );
  }
}

// ── Booking card ──────────────────────────────────────────────────────────────
class _BookingCard extends StatelessWidget {
  final BookingOut booking;
  final bool isCancelling;
  final VoidCallback onCancel;

  const _BookingCard({
    required this.booking,
    required this.isCancelling,
    required this.onCancel,
  });

  static const _statusConfig = {
    'confirmed': (
      color: Color(0xFF16A34A),
      bg: Color(0xFFDCFCE7),
      icon: Icons.check_circle_rounded,
      label: 'Confirmed',
    ),
    'completed': (
      color: Color(0xFF2563EB),
      bg: Color(0xFFDBEAFE),
      icon: Icons.done_all_rounded,
      label: 'Completed',
    ),
    'cancelled': (
      color: Color(0xFF6B7280),
      bg: Color(0xFFF3F4F6),
      icon: Icons.cancel_rounded,
      label: 'Cancelled',
    ),
    'pending': (
      color: Color(0xFFD97706),
      bg: Color(0xFFFEF3C7),
      icon: Icons.schedule_rounded,
      label: 'Pending',
    ),
  };

  static IconData _serviceIcon(String type) {
    final t = type.toLowerCase();
    if (t.contains('ac') || t.contains('air')) return Icons.ac_unit_rounded;
    if (t.contains('plumb')) return Icons.plumbing_rounded;
    if (t.contains('electr')) return Icons.bolt_rounded;
    if (t.contains('tutor') || t.contains('teach')) {
      return Icons.menu_book_rounded;
    }
    if (t.contains('clean')) return Icons.cleaning_services_rounded;
    if (t.contains('beauty') || t.contains('hair')) {
      return Icons.content_cut_rounded;
    }
    return Icons.home_repair_service_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _statusConfig[booking.status] ??
        (
          color: EzColors.inkSoft,
          bg: EzColors.cream2,
          icon: Icons.info_rounded,
          label: booking.statusLabel,
        );
    final canCancel =
        booking.status == 'confirmed' || booking.status == 'pending';

    return Container(
      decoration: BoxDecoration(
        color: EzColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: EzColors.border),
        boxShadow: [
          BoxShadow(
            color: EzColors.ink.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Main row ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Service icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: EzColors.yellow,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _serviceIcon(booking.serviceType),
                    size: 22,
                    color: EzColors.ink,
                  ),
                ),
                const SizedBox(width: 12),
                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.provider.name,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: EzColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        booking.serviceType,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: EzColors.muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: cfg.bg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(cfg.icon, size: 11, color: cfg.color),
                      const SizedBox(width: 4),
                      Text(
                        cfg.label,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: cfg.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Divider ─────────────────────────────────────────────
          Container(height: 1, color: EzColors.borderSoft),

          // ── Details row ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 13, color: EzColors.muted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        booking.locationText,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 12, color: EzColors.muted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (booking.provider.rating != null) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.star_rounded,
                          size: 13, color: EzColors.yellow),
                      const SizedBox(width: 3),
                      Text(
                        booking.provider.rating!.toStringAsFixed(1),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: EzColors.inkSoft,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 13, color: EzColors.muted),
                    const SizedBox(width: 4),
                    Text(
                      booking.formattedDate,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 12, color: EzColors.muted),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Cancel button ────────────────────────────────────────
          if (canCancel) ...[
            Container(height: 1, color: EzColors.borderSoft),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: isCancelling
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    )
                  : GestureDetector(
                      onTap: onCancel,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.cancel_outlined,
                                size: 14, color: Color(0xFFDC2626)),
                            const SizedBox(width: 6),
                            Text(
                              'Cancel Booking',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFDC2626),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
