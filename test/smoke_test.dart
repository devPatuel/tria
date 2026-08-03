import 'package:flutter_test/flutter_test.dart';
import 'package:tria/main.dart';

void main() {
  testWidgets('app boots into the session setup screen', (tester) async {
    await tester.pumpWidget(const TriaApp());
    expect(find.text('New session'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
