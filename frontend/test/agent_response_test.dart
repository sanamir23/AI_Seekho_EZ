import 'package:flutter_test/flutter_test.dart';
import 'package:ez_app/core/models/agent_response.dart';

void main() {
  test('AgentRunOut parses safe thinking steps', () {
    final response = AgentRunOut.fromJson({
      'status': 'completed',
      'conversation_id': 'conversation-1',
      'thinking_steps': [
        {
          'key': 'intent_parser',
          'title': 'Understanding request',
          'detail': 'Reading service, area, time, and language.',
          'status': 'done',
          'ms': 12,
        },
        {
          'key': 'booking_step',
          'title': 'Confirming booking',
          'detail': 'Securing the selected provider and time.',
          'status': 'done',
        },
      ],
    });

    expect(response.thinkingSteps, hasLength(2));
    expect(response.thinkingSteps!.first.key, 'intent_parser');
    expect(response.thinkingSteps!.first.ms, 12);
    expect(response.thinkingSteps!.last.status, 'done');
  });

  test('AgentRunOut tolerates malformed optional thinking steps', () {
    final response = AgentRunOut.fromJson({
      'status': 'needs_clarification',
      'conversation_id': 'conversation-2',
      'thinking_steps': 'not-a-list',
      'free_slots': 'not-a-list',
      'alternatives': 'not-a-list',
    });

    expect(response.status, 'needs_clarification');
    expect(response.thinkingSteps, isNull);
    expect(response.freeSlots, isNull);
    expect(response.alternatives, isNull);
  });
}
