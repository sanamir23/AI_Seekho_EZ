import 'package:flutter_test/flutter_test.dart';
import 'package:ez_app/main.dart';

void main() {
  testWidgets('EZ app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const EzApp());
    expect(find.byType(EzApp), findsOneWidget);
  });
}
