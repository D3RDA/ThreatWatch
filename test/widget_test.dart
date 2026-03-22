import 'package:flutter_test/flutter_test.dart';
import 'package:threatwatch_ai/main.dart';

void main() {
  testWidgets('ThreatWatch app renders', (WidgetTester tester) async {
    await tester.pumpWidget(const ThreatWatchApp());
    expect(find.text('ThreatWatch AI'), findsOneWidget);
  });
}
