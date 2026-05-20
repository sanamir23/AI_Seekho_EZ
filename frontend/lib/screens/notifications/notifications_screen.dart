import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/ez_colors.dart';
import 'notification_model.dart';
import 'notification_detail_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    final unreadCount = allNotifications.where((n) => n.isUnread).length;

    return Scaffold(
      backgroundColor: EzColors.cream,
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────
          Container(
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Notifications',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: EzColors.ink,
                              letterSpacing: -0.4,
                            ),
                          ),
                          if (unreadCount > 0)
                            Text(
                              '$unreadCount unread',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  color: EzColors.muted,
                                  fontWeight: FontWeight.w500),
                            ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('All notifications marked as read',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13, color: EzColors.ink)),
                          backgroundColor: EzColors.yellow,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          margin:
                              const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          duration: const Duration(seconds: 2),
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: EzColors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: EzColors.border),
                          boxShadow: [
                            BoxShadow(
                                color: EzColors.ink.withValues(alpha: 0.04),
                                blurRadius: 6,
                                offset: const Offset(0, 2))
                          ],
                        ),
                        child: Text(
                          'Mark all read',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: EzColors.inkSoft),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ).animate().fadeIn(duration: 350.ms),

          // ── List ──────────────────────────────────────────────
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: allNotifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) =>
                  _NotifCard(notif: allNotifications[i], index: i),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Notification card ────────────────────────────────────────────
class _NotifCard extends StatelessWidget {
  final NotifItem notif;
  final int index;
  const _NotifCard({required this.notif, required this.index});

  @override
  Widget build(BuildContext context) {
    final isCancellation = notif.type == NotifType.cancellation;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NotificationDetailScreen(notif: notif),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: EzColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isCancellation
                ? const Color(0xFFFFCDD2)
                : notif.isUnread
                    ? EzColors.yellowSoft
                    : EzColors.border,
            width: notif.isUnread ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: EzColors.ink
                  .withValues(alpha: notif.isUnread ? 0.06 : 0.03),
              blurRadius: notif.isUnread ? 12 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon bubble
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: notif.iconBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child:
                  Icon(notif.icon, size: 20, color: notif.iconColor),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notif.title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.5,
                            fontWeight: notif.isUnread
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: isCancellation
                                ? const Color(0xFFD93025)
                                : EzColors.ink,
                            height: 1.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (notif.isUnread)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isCancellation
                                ? const Color(0xFFD93025)
                                : EzColors.yellowDeep,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    notif.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: EzColors.inkSoft,
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded,
                          size: 11, color: EzColors.muted),
                      const SizedBox(width: 4),
                      Text(notif.time,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: EzColors.muted,
                              fontWeight: FontWeight.w500)),
                      const Spacer(),
                      // Inline CTA for cancellation
                      if (isCancellation)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: EzColors.ink,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text('Reschedule',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: EzColors.yellow)),
                        )
                      else
                        Row(
                          children: [
                            Text('View',
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: EzColors.muted)),
                            const SizedBox(width: 2),
                            const Icon(Icons.chevron_right_rounded,
                                size: 13, color: EzColors.muted),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: 60 * index))
        .fadeIn(duration: 350.ms)
        .slideY(begin: 0.12, end: 0, duration: 350.ms);
  }
}
