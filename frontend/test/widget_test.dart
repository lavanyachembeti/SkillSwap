import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';

void main() {
  testWidgets('SkillSwap splash screen smoke test', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger initial frame.
    await tester.pumpWidget(const SkillSwapApp());

    // Verify that SkillSwap title and tagline exist on splash screen.
    expect(find.text('SkillSwap'), findsOneWidget);
    expect(find.text('Learn. Share. Grow.'), findsOneWidget);

    // Advance timer by 2 seconds to complete splash screen timer
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
  });
}
