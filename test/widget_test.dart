import 'package:flutter_test/flutter_test.dart';
import 'package:officefiles/main.dart';

void main() {
  testWidgets('Word Viewer smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the title 'Word Viewer' is present.
    expect(find.text('Word Viewer'), findsOneWidget);

    // Verify that the helper text is present.
    expect(find.text('Offline Word Engine'), findsOneWidget);
  });
}
