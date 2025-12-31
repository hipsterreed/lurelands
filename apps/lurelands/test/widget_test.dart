import 'package:flutter_test/flutter_test.dart';
import 'package:lurelands/main.dart';

void main() {
  testWidgets('Lurelands app starts correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const LurelandsApp());

    // Verify that the main menu is displayed
    expect(find.text('LURELANDS'), findsOneWidget);
    expect(find.text('ENTER WORLD'), findsOneWidget);
  });
}
