// Models matching backend Pydantic schemas (booking.py)

class ProviderOut {
  final String id;
  final String name;
  final String category;
  final String? area;
  final String? address;
  final String? phone;
  final double? rating;

  const ProviderOut({
    required this.id,
    required this.name,
    required this.category,
    this.area,
    this.address,
    this.phone,
    this.rating,
  });

  factory ProviderOut.fromJson(Map<String, dynamic> j) => ProviderOut(
        id: j['id'],
        name: j['name'],
        category: j['category'],
        area: j['area'],
        address: j['address'],
        phone: j['phone'],
        rating: j['rating'] != null ? (j['rating']).toDouble() : null,
      );
}

class BookingOut {
  final String id;
  final String status;
  final String serviceType;
  final String locationText;
  final String scheduledAt;
  final String createdAt;
  final String? agentTraceId;
  final ProviderOut provider;

  const BookingOut({
    required this.id,
    required this.status,
    required this.serviceType,
    required this.locationText,
    required this.scheduledAt,
    required this.createdAt,
    this.agentTraceId,
    required this.provider,
  });

  factory BookingOut.fromJson(Map<String, dynamic> j) => BookingOut(
        id: j['id'],
        status: j['status'],
        serviceType: j['service_type'],
        locationText: j['location_text'],
        scheduledAt: j['scheduled_at'],
        createdAt: j['created_at'],
        agentTraceId: j['agent_trace_id'],
        provider: ProviderOut.fromJson(j['provider']),
      );

  /// Human-readable scheduled date/time
  String get formattedDate {
    try {
      final dt = DateTime.parse(scheduledAt).toLocal();
      final months = [
        'Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'
      ];
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final ampm = dt.hour < 12 ? 'AM' : 'PM';
      final min = dt.minute.toString().padLeft(2, '0');
      return '${months[dt.month - 1]} ${dt.day} · $hour:$min $ampm';
    } catch (_) {
      return scheduledAt;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'confirmed':
        return 'Confirmed';
      case 'cancelled':
        return 'Cancelled';
      case 'completed':
        return 'Completed';
      default:
        return status;
    }
  }
}

class BookingDetailOut extends BookingOut {
  final String? reasoning;
  final List<Map<String, dynamic>>? traceSteps;
  final List<Map<String, dynamic>>? notifications;
  final Map<String, dynamic>? scoreBreakdown;
  final Map<String, dynamic>? priceRange;
  final List<Map<String, dynamic>>? candidateProviders;

  const BookingDetailOut({
    required super.id,
    required super.status,
    required super.serviceType,
    required super.locationText,
    required super.scheduledAt,
    required super.createdAt,
    super.agentTraceId,
    required super.provider,
    this.reasoning,
    this.traceSteps,
    this.notifications,
    this.scoreBreakdown,
    this.priceRange,
    this.candidateProviders,
  });

  factory BookingDetailOut.fromJson(Map<String, dynamic> j) {
    return BookingDetailOut(
      id: j['id'],
      status: j['status'],
      serviceType: j['service_type'],
      locationText: j['location_text'],
      scheduledAt: j['scheduled_at'],
      createdAt: j['created_at'],
      agentTraceId: j['agent_trace_id'],
      provider: ProviderOut.fromJson(j['provider']),
      reasoning: j['reasoning'],
      traceSteps: j['trace_steps'] != null
          ? List<Map<String, dynamic>>.from(j['trace_steps'])
          : null,
      notifications: j['notifications'] != null
          ? List<Map<String, dynamic>>.from(j['notifications'])
          : null,
      scoreBreakdown: j['score_breakdown'] != null
          ? Map<String, dynamic>.from(j['score_breakdown'])
          : null,
      priceRange: j['price_range'] != null
          ? Map<String, dynamic>.from(j['price_range'])
          : null,
      candidateProviders: j['candidate_providers'] != null
          ? List<Map<String, dynamic>>.from(j['candidate_providers'])
          : null,
    );
  }
}
