import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/ez_colors.dart';
import '../../core/models/booking.dart';
import '../../core/services/api_service.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  List<BookingOut> _bookings = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ApiService.instance.listBookings();
      if (mounted) setState(() => _bookings = list);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load bookings.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancel(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: EzColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Cancel Booking',
            style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700, color: EzColors.ink)),
        content: Text('Are you sure you want to cancel this booking?',
            style: GoogleFonts.plusJakartaSans(
                color: EzColors.inkSoft, fontWeight: FontWeight.w500)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Keep it',
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700, color: EzColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Cancel',
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700, color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService.instance.cancelBooking(id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel: ${e.toString()}',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
            backgroundColor: EzColors.ink,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        );
      }
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
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('My Bookings',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: EzColors.ink,
                              letterSpacing: -0.5)),
                      Text('Your scheduled services',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: EzColors.muted,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _load,
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
                      child: const Icon(Icons.refresh_rounded,
                          size: 18, color: EzColors.ink),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms),

            // Content
            Expanded(
              child: _loading
                  ? _buildSkeleton()
                  : _error != null
                      ? _buildError()
                      : _bookings.isEmpty
                          ? _buildEmpty()
                          : RefreshIndicator(
                              onRefresh: _load,
                              color: EzColors.yellow,
                              child: ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                                itemCount: _bookings.length,
                                itemBuilder: (_, i) => _BookingCard(
                                  booking: _bookings[i],
                                  onCancel: _bookings[i].status == 'confirmed'
                                      ? () => _cancel(_bookings[i].id)
                                      : null,
                                )
                                    .animate()
                                    .fadeIn(
                                        delay: Duration(milliseconds: i * 80),
                                        duration: 300.ms)
                                    .slideY(
                                        begin: 0.1,
                                        end: 0,
                                        delay: Duration(milliseconds: i * 80),
                                        duration: 300.ms),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: 3,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 130,
        decoration: BoxDecoration(
          color: EzColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: EzColors.border),
        ),
      )
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .shimmer(
              duration: 1200.ms,
              color: EzColors.cream2),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 44, color: EzColors.muted2),
          const SizedBox(height: 12),
          Text(_error!,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 15, fontWeight: FontWeight.w600, color: EzColors.ink)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _load,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: EzColors.ink,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('Retry',
                  style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700, color: EzColors.yellow)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: EzColors.yellowGlow,
              shape: BoxShape.circle,
              border: Border.all(color: EzColors.yellow),
            ),
            child: const Icon(Icons.calendar_today_rounded,
                size: 34, color: EzColors.yellowDeep),
          ),
          const SizedBox(height: 16),
          Text('No bookings yet',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: EzColors.ink)),
          const SizedBox(height: 6),
          Text('Your booked services will appear here.',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, color: EzColors.muted, fontWeight: FontWeight.w500)),
        ],
      ).animate().fadeIn(duration: 400.ms).scale(
          begin: const Offset(0.9, 0.9),
          end: const Offset(1, 1),
          duration: 400.ms),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final BookingOut booking;
  final VoidCallback? onCancel;

  const _BookingCard({required this.booking, this.onCancel});

  Color get _statusColor {
    switch (booking.status) {
      case 'confirmed':
        return EzColors.success;
      case 'cancelled':
        return Colors.red;
      case 'completed':
        return EzColors.info;
      default:
        return EzColors.muted;
    }
  }

  Color get _statusBg {
    switch (booking.status) {
      case 'confirmed':
        return EzColors.successSoft;
      case 'cancelled':
        return const Color(0xFFFFEEEE);
      case 'completed':
        return const Color(0xFFEEF2FF);
      default:
        return EzColors.cream2;
    }
  }

  String get _initials => booking.provider.name
      .split(' ')
      .map((w) => w.isNotEmpty ? w[0] : '')
      .take(2)
      .join();

  String get _categoryLabel => booking.serviceType
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : w)
      .join(' ');

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: EzColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: EzColors.border),
        boxShadow: [
          BoxShadow(
              color: EzColors.ink.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFCD24A), Color(0xFFFFE988)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(_initials,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
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
                            child: Text(booking.provider.name,
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: EzColors.ink)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _statusBg,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(booking.statusLabel,
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: _statusColor)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                          '$_categoryLabel · ${booking.provider.area ?? booking.locationText}',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              color: EzColors.muted,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            Divider(color: EzColors.border, height: 1),
            const SizedBox(height: 10),

            Row(
              children: [
                const Icon(Icons.calendar_today_rounded,
                    size: 13, color: EzColors.muted),
                const SizedBox(width: 5),
                Text(booking.formattedDate,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: EzColors.inkSoft,
                        fontWeight: FontWeight.w600)),
                if (booking.provider.rating != null) ...[
                  const Spacer(),
                  const Icon(Icons.star_rounded,
                      size: 13, color: EzColors.yellowDeep),
                  const SizedBox(width: 3),
                  Text(booking.provider.rating!.toStringAsFixed(1),
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: EzColors.ink)),
                ],
              ],
            ),

            if (onCancel != null) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: onCancel,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: EzColors.cream2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: EzColors.border),
                  ),
                  child: Text('Cancel Booking',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: EzColors.inkSoft)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
