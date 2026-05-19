import 'package:ez_app/core/models/agent_response.dart';
import 'package:ez_app/screens/composer/chat_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('buildDynamicThinkingStepsForAgent handles second prompt safely', () {
    const previous = AgentRunOut(
      status: 'completed',
      conversationId: 'conv-1',
      intent: IntentParsed(
        serviceType: 'plumber',
        area: 'F-10',
        scheduledAt: '2026-05-20T09:00:00+05:00',
      ),
    );

    final steps = buildDynamicThinkingStepsForAgent(
      lastData: previous,
      latestUserText: 'Need electrician in G-13 tomorrow at 9am',
    );

    expect(steps, isNotEmpty);
    expect(steps.first['title'], 'All details confirmed');
    expect(steps.first['sub'], contains('Electrician'));
    expect(steps.first['sub'], contains('G-13'));
  });

  test('buildDynamicThinkingStepsForAgent infers text when intent is absent',
      () {
    const previous = AgentRunOut(
      status: 'completed',
      conversationId: 'conv-1',
    );

    final steps = buildDynamicThinkingStepsForAgent(
      lastData: previous,
      latestUserText: 'Need electrician in G-13 tomorrow at 9am',
    );

    expect(steps, isNotEmpty);
    expect(steps.first['title'], 'All details confirmed');
    expect(steps.first['sub'], contains('Electrician'));
    expect(steps.first['sub'], contains('G-13'));
  });
}
