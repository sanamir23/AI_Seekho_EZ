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
        intentType: j['intent_type']?.toString() ?? 'book',
        serviceType: j['service_type']?.toString(),
        area: j['area']?.toString(),
        scheduledAt: j['scheduled_at']?.toString(),
        confidence: (j['confidence'] ?? 0.0).toDouble(),
        language: j['language']?.toString(),
      );
}

class ProviderBrief {
  final String id;
  final String name;
  final String category;
  final String? area;
  final double? rating;
  final double? distanceKm;
  final double? score;
  final Map<String, dynamic>? scoreBreakdown;

  const ProviderBrief({
    required this.id,
    required this.name,
    required this.category,
    this.area,
    this.rating,
    this.distanceKm,
    this.score,
    this.scoreBreakdown,
  });

  factory ProviderBrief.fromJson(Map<String, dynamic> j) => ProviderBrief(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? 'Unknown',
        category: j['category']?.toString() ?? '',
        area: j['area']?.toString(),
        rating: j['rating'] != null ? (j['rating']).toDouble() : null,
        distanceKm:
            j['distance_km'] != null ? (j['distance_km']).toDouble() : null,
        score: j['score'] != null ? (j['score']).toDouble() : null,
        scoreBreakdown: j['score_breakdown'] != null
            ? Map<String, dynamic>.from(j['score_breakdown'])
            : null,
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
        id: j['id']?.toString() ?? '',
        status: j['status']?.toString() ?? '',
        scheduledAt: j['scheduled_at']?.toString() ?? '',
        providerId: j['provider_id']?.toString() ?? '',
      );
}

class FollowupBrief {
  final String notificationId;
  final String reminderAt;

  const FollowupBrief(
      {required this.notificationId, required this.reminderAt});

  factory FollowupBrief.fromJson(Map<String, dynamic> j) => FollowupBrief(
        notificationId: j['notification_id']?.toString() ?? '',
        reminderAt: j['reminder_at']?.toString() ?? '',
      );
}

/// Matches backend: SlotOption(label, iso)
class SlotOption {
  final String label;
  final String iso;

  const SlotOption({required this.label, required this.iso});

  factory SlotOption.fromJson(Map<String, dynamic> j) => SlotOption(
        label: j['label']?.toString() ?? '',
        iso: j['iso']?.toString() ?? '',
      );
}

/// Matches backend: PriceRange(min_pkr, max_pkr)
class PriceRange {
  final int minPkr;
  final int maxPkr;

  const PriceRange({required this.minPkr, required this.maxPkr});

  factory PriceRange.fromJson(Map<String, dynamic> j) => PriceRange(
        minPkr: (j['min_pkr'] ?? 0) is int
            ? j['min_pkr']
            : (j['min_pkr'] ?? 0).toInt(),
        maxPkr: (j['max_pkr'] ?? 0) is int
            ? j['max_pkr']
            : (j['max_pkr'] ?? 0).toInt(),
      );
}

class ThinkingStep {
  final String key;
  final String title;
  final String detail;
  final String status;
  final int? ms;

  const ThinkingStep({
    required this.key,
    required this.title,
    required this.detail,
    required this.status,
    this.ms,
  });

  factory ThinkingStep.fromJson(Map<String, dynamic> j) => ThinkingStep(
        key: j['key']?.toString() ?? '',
        title: j['title']?.toString() ?? 'Working on request',
        detail: j['detail']?.toString() ?? 'Advancing your request safely.',
        status: j['status']?.toString() ?? 'done',
        ms: j['ms'] is int
            ? j['ms'] as int
            : j['ms'] is num
                ? (j['ms'] as num).round()
                : null,
      );
}

/// Top-level response from POST /api/service-requests
class AgentRunOut {
  final String status; // completed | needs_clarification | abandoned
  final String conversationId;
  final List<ThinkingStep>? thinkingSteps;

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
  final PriceRange? priceRange;

  // needs_clarification
  final String? question;
  final IntentParsed? partialIntent;
  final List<SlotOption>? freeSlots;
  final List<ProviderBrief>? alternatives;

  // abandoned
  final String? reason;

  const AgentRunOut({
    required this.status,
    required this.conversationId,
    this.thinkingSteps,
    this.intent,
    this.selectedProvider,
    this.reasoning,
    this.formattedMessage,
    this.suggestions,
    this.booking,
    this.followup,
    this.traceId,
    this.traceSteps,
    this.priceRange,
    this.question,
    this.partialIntent,
    this.freeSlots,
    this.alternatives,
    this.reason,
  });

  factory AgentRunOut.fromJson(Map<String, dynamic> j) {
    List<ThinkingStep>? thinkingSteps;
    try {
      thinkingSteps = j['thinking_steps'] is List
          ? (j['thinking_steps'] as List)
              .map((s) => ThinkingStep.fromJson(s as Map<String, dynamic>))
              .toList()
          : null;
    } catch (_) {
      thinkingSteps = null;
    }

    List<SlotOption>? slots;
    try {
      slots = j['free_slots'] != null
          ? (j['free_slots'] as List)
              .map((s) => SlotOption.fromJson(s as Map<String, dynamic>))
              .toList()
          : null;
    } catch (_) {
      slots = null;
    }

    List<ProviderBrief>? alts;
    try {
      alts = j['alternatives'] != null
          ? (j['alternatives'] as List)
              .map((p) => ProviderBrief.fromJson(p as Map<String, dynamic>))
              .toList()
          : null;
    } catch (_) {
      alts = null;
    }

    PriceRange? priceRange;
    try {
      priceRange = j['price_range'] != null
          ? PriceRange.fromJson(j['price_range'] as Map<String, dynamic>)
          : null;
    } catch (_) {
      priceRange = null;
    }

    return AgentRunOut(
      status: j['status']?.toString() ?? 'abandoned',
      conversationId: j['conversation_id']?.toString() ?? '',
      thinkingSteps: thinkingSteps,
      intent:
          j['intent'] != null ? IntentParsed.fromJson(j['intent']) : null,
      selectedProvider: j['selected_provider'] != null
          ? ProviderBrief.fromJson(j['selected_provider'])
          : null,
      reasoning: j['reasoning']?.toString(),
      formattedMessage: j['formatted_message']?.toString(),
      suggestions: j['suggestions'] != null
          ? List<String>.from(
              (j['suggestions'] as List).map((e) => e.toString()))
          : null,
      booking: j['booking'] != null
          ? BookingBrief.fromJson(j['booking'])
          : null,
      followup: j['followup'] != null
          ? FollowupBrief.fromJson(j['followup'])
          : null,
      traceId: j['trace_id']?.toString(),
      traceSteps: j['trace_steps'] != null
          ? List<Map<String, dynamic>>.from(j['trace_steps'])
          : null,
      priceRange: priceRange,
      question: j['question']?.toString(),
      partialIntent: j['partial_intent'] != null
          ? IntentParsed.fromJson(j['partial_intent'])
          : null,
      freeSlots: slots,
      alternatives: alts,
      reason: j['reason']?.toString(),
    );
  }
}
