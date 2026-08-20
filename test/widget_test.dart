import 'package:flutter_test/flutter_test.dart';
import 'package:spend_book/main.dart';

void main() {
  testWidgets('SpendBook smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that our app header and elements are present.
    expect(find.text('SpendBook'), findsOneWidget);
    expect(find.text('Track Payment'), findsOneWidget);
    expect(find.text('Save Payment'), findsOneWidget);
  });
}
