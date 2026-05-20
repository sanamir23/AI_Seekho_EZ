import 'package:flutter/material.dart';
import '../../core/theme/ez_colors.dart';

enum NotifType {
  cancellation,
  arrival,
  appointment,
  rating,
  promo,
  reminder,
}

class NotifItem {
  final NotifType type;
  final String title;
  final String body;
  final String time;
  final bool isUnread;

  const NotifItem({
    required this.type,
    required this.title,
    required this.body,
    required this.time,
    this.isUnread = false,
  });

  IconData get icon {
    switch (type) {
      case NotifType.cancellation:
        return Icons.cancel_schedule_send_rounded;
      case NotifType.arrival:
        return Icons.directions_car_rounded;
      case NotifType.appointment:
        return Icons.calendar_today_rounded;
      case NotifType.rating:
        return Icons.star_rounded;
      case NotifType.promo:
        return Icons.local_offer_rounded;
      case NotifType.reminder:
        return Icons.notifications_active_rounded;
    }
  }

  Color get iconBg {
    switch (type) {
      case NotifType.cancellation:
        return const Color(0xFFFFECEC);
      case NotifType.arrival:
        return const Color(0xFFFCD24A);
      case NotifType.appointment:
        return const Color(0xFFFFE988);
      case NotifType.rating:
        return const Color(0xFFFFF5C2);
      case NotifType.promo:
        return const Color(0xFFF4EFE2);
      case NotifType.reminder:
        return const Color(0xFFFFE988);
    }
  }

  Color get iconColor {
    switch (type) {
      case NotifType.cancellation:
        return const Color(0xFFD93025);
      default:
        return EzColors.ink;
    }
  }

  bool get isCancellation => type == NotifType.cancellation;
}

/// All notifications in order (newest first).
final List<NotifItem> allNotifications = [
  const NotifItem(
    type: NotifType.cancellation,
    title: 'Appointment cancelled by provider',
    body:
        'Hassan (Deep Cleaning) has cancelled your appointment for today. He is requesting to reschedule for tomorrow at 2:00 PM.',
    time: '5 min ago',
    isUnread: true,
  ),
  const NotifItem(
    type: NotifType.arrival,
    title: 'Your provider is on the way!',
    body:
        'Ali (AC Technician) will arrive in approximately 10 minutes. Please make sure someone is available.',
    time: 'Just now',
    isUnread: true,
  ),
  const NotifItem(
    type: NotifType.appointment,
    title: 'Appointment scheduled for today',
    body:
        'Deep Cleaning service is confirmed for today at 3:00 PM. Tap to view your booking details.',
    time: '2h ago',
    isUnread: true,
  ),
  const NotifItem(
    type: NotifType.rating,
    title: 'Rate your experience',
    body:
        'How was your Plumbing service with Usman? Your feedback helps other customers like you.',
    time: 'Yesterday',
    isUnread: false,
  ),
  const NotifItem(
    type: NotifType.promo,
    title: '20% off on your next booking 🎉',
    body:
        'Use code EZ20 to get 20% off on any home service booked before Friday. Limited slots!',
    time: '2 days ago',
    isUnread: false,
  ),
  const NotifItem(
    type: NotifType.reminder,
    title: 'Service reminder',
    body:
        "Your AC hasn't been serviced in 6 months. Book a maintenance check before summer hits.",
    time: '3 days ago',
    isUnread: false,
  ),
];
