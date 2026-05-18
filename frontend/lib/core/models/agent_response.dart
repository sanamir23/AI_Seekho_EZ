// Models matching backend Pydantic schemas (service_request.py)

class IntentParsed {
  final String intentType;
  final String? serviceType;
  final String? area;
  final String? scheduledAt;
  final double confidence;
  final String? language;

  const IntentParsed({
    this.intentType = 'book',
    this.serviceType,
    this.area,
    this.scheduledAt,
    this.confidence = 0.0,
    this.language,
  });

  factory IntentParsed.fromJson(Map<String, dynamic> j) => IntentParsed(
        intentType: j['intent_type'] ?? 'book',
        serviceType: j['service_type'],
        area: j['area'],
        scheduledAt: j['scheduled_at'],
        confidence: (j['confidence'] ?? 0.0).toDouble(),
        language: j['language'],
      );
}

class ProviderBrief {
  final String id;
  final String name;
  final String category;
  final String? area;
  final double? rating;
  final double? distanceKm;

  const ProviderBrief({
    required this.id,
    required this.name,
    required this.category,
    this.area,
    this.rating,
    this.distanceKm,
  });

  factory ProviderBrief.fromJson(Map<String, dynamic> j) => ProviderBrief(
        id: j['id'],
        name: j['name'],
        category: j['category'],
        area: j['area'],
        rating: j['rating'] != null ? (j['rating']).toDouble() : null,
        distanceKm:
            j['distance_km'] != null ? (j['distance_km']).toDouble() : null,
      );
}

class BookingBrief {
  final String id;
  final String status;
  final String scheduledAt;
  final String providerId;

  const BookingBrief({
    required this.id,
    required this.status,
    required this.scheduledAt,
    required this.providerId,
  });

  factory BookingBrief.fromJson(Map<String, dynamic> j) => BookingBrief(
        id: j['id'],
        status: j['status'],
        scheduledAt: j['scheduled_at'],
        providerId: j['provider_id'],
      );
}

class FollowupBrief {
  final String notificationId;
  final String reminderAt;

  const FollowupBrief(
      {required this.notificationId, required this.reminderAt});

  factory FollowupBrief.fromJson(Map<String, dynamic> j) => FollowupBrief(
        notificationId: j['notification_id'],
        reminderAt: j['reminder_at'],
      );
}

/// Top-level response from POST /api/service-requests
class AgentRunOut {
  final String status; // completed | needs_clarification | abandoned
  final String conversationId;

  // completed
  final IntentParsed? intent;
  final ProviderBrief? selectedProvider;
  final String? reasoning;
  final String? formattedMessage;
  final List<String>? suggestions;
  final BookingBrief? booking;
  final FollowupBrief? followup;
  final String? traceId;
  final List<Map<String, dynamic>>? traceSteps;

  // needs_clarification
  final String? question;
  final IntentParsed? partialIntent;

  // abandoned
  final String? reason;

  const AgentRunOut({
    required this.status,
    required this.conversationId,
    this.intent,
    this.selectedProvider,
    this.reasoning,
    this.formattedMessage,
    this.suggestions,
    this.booking,
    this.followup,
    this.traceId,
    this.traceSteps,
    this.question,
    this.partialIntent,
    this.reason,
  });

  factory AgentRunOut.fromJson(Map<String, dynamic> j) => AgentRunOut(
        status: j['status'],
        conversationId: j['conversation_id'],
        intent: j['intent'] != null ? IntentParsed.fromJson(j['intent']) : null,
        selectedProvider: j['selected_provider'] != null
            ? ProviderBrief.fromJson(j['selected_provider'])
            : null,
        reasoning: j['reasoning'],
        formattedMessage: j['formatted_message'],
        suggestions: j['suggestions'] != null
            ? List<String>.from(j['suggestions'])
            : null,
        booking: j['booking'] != null
            ? BookingBrief.fromJson(j['booking'])
            : null,
        followup: j['followup'] != null
            ? FollowupBrief.fromJson(j['followup'])
            : null,
        traceId: j['trace_id'],
        traceSteps: j['trace_steps'] != null
            ? List<Map<String, dynamic>>.from(j['trace_steps'])
            : null,
        question: j['question'],
        partialIntent: j['partial_intent'] != null
            ? IntentParsed.fromJson(j['partial_intent'])
            : null,
        reason: j['reason'],
      );
}
