import 'package:flutter_test/flutter_test.dart';
import 'package:the_life_list/main.dart';

void main() {
  testWidgets('App builds', (WidgetTester tester) async {
    await tester.pumpWidget(const TheLifeListApp());
    // First frame may still be resolving SharedPreferences / theme.
    await tester.pump();
    expect(find.byType(TheLifeListApp), findsOneWidget);
  });
}
