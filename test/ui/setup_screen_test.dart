import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tria/domain/session_config.dart';
import 'package:tria/ui/setup_screen.dart';

void main() {
  Widget wrap(void Function(SessionConfig) onStart) =>
      MaterialApp(home: SetupScreen(onStart: onStart));

  testWidgets('cannot start without a source folder', (tester) async {
    await tester.pumpWidget(wrap((_) {}));

    final startButton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(startButton.onPressed, isNull);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('adding a destination shows it in the list', (tester) async {
    await tester.pumpWidget(wrap((_) {}));

    await tester.enterText(find.byKey(const Key('destination-label')), 'Family');
    await tester.enterText(find.byKey(const Key('destination-path')), '/sorted/family');
    await tester.tap(find.byKey(const Key('add-destination')));
    await tester.pump();

    expect(find.text('Family'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('rejects a tenth destination', (tester) async {
    await tester.pumpWidget(wrap((_) {}));

    for (var i = 1; i <= 10; i++) {
      await tester.enterText(find.byKey(const Key('destination-label')), 'D$i');
      await tester.enterText(find.byKey(const Key('destination-path')), '/d$i');
      await tester.tap(find.byKey(const Key('add-destination')));
      await tester.pump();
    }

    // A ListView only builds what is on screen, so scroll to the bottom before
    // concluding anything about the last entries.
    await tester.dragUntilVisible(
      find.widgetWithText(ListTile, 'D9'),
      find.byKey(const Key('destination-list')),
      const Offset(0, -80),
    );

    // Scoped to the list: a bare find.text('D10') also matches the text still
    // sitting in the input field, which says nothing about what was added.
    expect(find.widgetWithText(ListTile, 'D9'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'D10'), findsNothing);
    expect(find.text('All nine slots are taken'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
