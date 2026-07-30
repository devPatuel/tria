import 'package:flutter_test/flutter_test.dart';
import 'package:tria/main.dart';

void main() {
  testWidgets('app boots and shows its name', (tester) async {
    await tester.pumpWidget(const TriaApp());
    expect(find.text('Tría'), findsOneWidget);
  });
}
