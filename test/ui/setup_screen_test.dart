import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tria/core/fs/folder_access.dart';
import 'package:tria/domain/session_config.dart';
import 'package:tria/ui/setup_screen.dart';

/// The screen is about the decision, not the disk: whether a folder is really
/// writable is covered by `test/core/fs/folder_access_test.dart`.
class _FakeAccess extends FolderAccess {
  final Set<String> unwritable;

  _FakeAccess({this.unwritable = const {}});

  @override
  Future<bool> isWritable(String path) async => !unwritable.contains(path);
}

void main() {
  Widget wrap(void Function(SessionConfig) onStart, {FolderAccess? access}) =>
      MaterialApp(
        home: SetupScreen(
          onStart: onStart,
          access: access ?? _FakeAccess(),
        ),
      );

  testWidgets('cannot start without a source folder', (tester) async {
    await tester.pumpWidget(wrap((_) {}));

    final startButton = tester.widget<FilledButton>(
        find.byKey(const Key('start-sorting')));
    expect(startButton.onPressed, isNull);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('says why it cannot start yet', (tester) async {
    await tester.pumpWidget(wrap((_) {}));

    expect(find.text('Choose a source folder to start'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('asks for a destination once the folder is set', (tester) async {
    await tester.pumpWidget(wrap((_) {}));

    await tester.enterText(find.byKey(const Key('source-root')), '/photos');
    await tester.pump();

    expect(find.text('Add at least one destination'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('starts once both are given', (tester) async {
    SessionConfig? started;
    await tester.pumpWidget(wrap((c) => started = c));

    await tester.enterText(find.byKey(const Key('source-root')), '/photos');
    await tester.enterText(find.byKey(const Key('destination-label')), 'Family');
    await tester.enterText(find.byKey(const Key('destination-path')), '/sorted');
    await tester.tap(find.byKey(const Key('add-destination')));
    await tester.pump();
    await tester.tap(find.text('Start sorting'));
    await tester.pump();

    expect(started, isNotNull);
    expect(started!.sourceRoot, '/photos');
    expect(started!.destinations.single.label, 'Family');
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

  testWidgets('refuses to start when the destination cannot be written to',
      (tester) async {
    SessionConfig? started;
    await tester.pumpWidget(wrap(
      (c) => started = c,
      access: _FakeAccess(unwritable: {'/sorted'}),
    ));

    await tester.enterText(find.byKey(const Key('source-root')), '/photos');
    await tester.enterText(find.byKey(const Key('destination-label')), 'Family');
    await tester.enterText(find.byKey(const Key('destination-path')), '/sorted');
    await tester.tap(find.byKey(const Key('add-destination')));
    await tester.pump();
    await tester.tap(find.text('Start sorting'));
    await tester.pumpAndSettle();

    expect(started, isNull);
    expect(find.textContaining('Family'), findsWidgets);
    expect(find.textContaining('cannot be written to'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('refuses to start when the source folder is read-only',
      (tester) async {
    SessionConfig? started;
    await tester.pumpWidget(wrap(
      (c) => started = c,
      access: _FakeAccess(unwritable: {'/photos'}),
    ));

    await tester.enterText(find.byKey(const Key('source-root')), '/photos');
    await tester.enterText(find.byKey(const Key('destination-label')), 'Family');
    await tester.enterText(find.byKey(const Key('destination-path')), '/sorted');
    await tester.tap(find.byKey(const Key('add-destination')));
    await tester.pump();
    await tester.tap(find.text('Start sorting'));
    await tester.pumpAndSettle();

    expect(started, isNull);
    expect(find.textContaining('cannot be written to'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
