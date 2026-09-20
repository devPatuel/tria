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
  /// What the next system dialog will return. Paths reach the screen only this
  /// way, because on macOS choosing a folder in the dialog is what grants the
  /// sandboxed app access to it.
  late String? nextPick;
  late int dialogsOpened;

  setUp(() {
    nextPick = '/picked/folder';
    dialogsOpened = 0;
  });

  /// The smallest window the app allows (see MainFlutterWindow.swift). Testing
  /// at the default 800x600 would fail on a size the user can never produce.
  Future<void> atMinimumWindowSize(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(960, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  Widget wrap(void Function(SessionConfig) onStart, {FolderAccess? access}) =>
      MaterialApp(
        home: SetupScreen(
          onStart: onStart,
          access: access ?? _FakeAccess(),
          pickFolder: () async {
            dialogsOpened++;
            return nextPick;
          },
        ),
      );

  Future<void> chooseSource(WidgetTester tester, String path) async {
    nextPick = path;
    await tester.tap(find.byKey(const Key('source-root')));
    await tester.pumpAndSettle();
  }

  Future<void> addDestination(
    WidgetTester tester,
    String label,
    String path,
  ) async {
    await tester.enterText(find.byKey(const Key('destination-label')), label);
    nextPick = path;
    await tester.tap(find.byKey(const Key('destination-path')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-destination')));
    await tester.pump();
  }

  testWidgets('cannot start without a source folder', (tester) async {
    await atMinimumWindowSize(tester);
    await tester.pumpWidget(wrap((_) {}));

    final startButton =
        tester.widget<FilledButton>(find.byKey(const Key('start-sorting')));
    expect(startButton.onPressed, isNull);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('says why it cannot start yet', (tester) async {
    await atMinimumWindowSize(tester);
    await tester.pumpWidget(wrap((_) {}));

    expect(find.text('Choose a source folder to start'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('asks for a destination once the folder is set', (tester) async {
    await atMinimumWindowSize(tester);
    await tester.pumpWidget(wrap((_) {}));

    await chooseSource(tester, '/photos');

    expect(find.text('Add at least one destination'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('starts once both are given', (tester) async {
    SessionConfig? started;
    await atMinimumWindowSize(tester);
    await tester.pumpWidget(wrap((c) => started = c));

    await chooseSource(tester, '/photos');
    await addDestination(tester, 'Family', '/sorted');
    await tester.tap(find.text('Start sorting'));
    await tester.pumpAndSettle();

    expect(started, isNotNull);
    expect(started!.sourceRoot, '/photos');
    expect(started!.destinations.single.label, 'Family');
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('adding a destination shows it in the list', (tester) async {
    await atMinimumWindowSize(tester);
    await tester.pumpWidget(wrap((_) {}));

    await addDestination(tester, 'Family', '/sorted/family');

    expect(find.text('Family'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('rejects a tenth destination', (tester) async {
    await atMinimumWindowSize(tester);
    await tester.pumpWidget(wrap((_) {}));

    for (var i = 1; i <= 10; i++) {
      await addDestination(tester, 'D$i', '/d$i');
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
    await atMinimumWindowSize(tester);
    await tester.pumpWidget(wrap(
      (c) => started = c,
      access: _FakeAccess(unwritable: {'/sorted'}),
    ));

    await chooseSource(tester, '/photos');
    await addDestination(tester, 'Family', '/sorted');
    await tester.tap(find.text('Start sorting'));
    await tester.pumpAndSettle();

    expect(started, isNull);
    expect(find.textContaining('Family'), findsWidgets);
    expect(find.textContaining('cannot be written to'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('refuses to start when the source folder is read-only',
      (tester) async {
    SessionConfig? started;
    await atMinimumWindowSize(tester);
    await tester.pumpWidget(wrap(
      (c) => started = c,
      access: _FakeAccess(unwritable: {'/photos'}),
    ));

    await chooseSource(tester, '/photos');
    await addDestination(tester, 'Family', '/sorted');
    await tester.tap(find.text('Start sorting'));
    await tester.pumpAndSettle();

    expect(started, isNull);
    expect(find.textContaining('cannot be written to'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('a path cannot be typed in: macOS grants access only to picked folders',
      (tester) async {
    await atMinimumWindowSize(tester);
    await tester.pumpWidget(wrap((_) {}));

    final source =
        tester.widget<TextField>(find.byKey(const Key('source-root')));
    final destination =
        tester.widget<TextField>(find.byKey(const Key('destination-path')));

    expect(source.readOnly, isTrue);
    expect(destination.readOnly, isTrue);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('tapping a path field opens the system dialog', (tester) async {
    await atMinimumWindowSize(tester);
    await tester.pumpWidget(wrap((_) {}));

    await chooseSource(tester, '/picked/photos');

    expect(dialogsOpened, 1);
    expect(find.text('/picked/photos'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('a folder it cannot write to points at the dialog, not at the drive',
      (tester) async {
    await atMinimumWindowSize(tester);
    await tester.pumpWidget(wrap(
      (_) {},
      access: _FakeAccess(unwritable: {'/sorted'}),
    ));

    await chooseSource(tester, '/photos');
    await addDestination(tester, 'Family', '/sorted');
    await tester.tap(find.text('Start sorting'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Choose folder'), findsWidgets);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('choosing a folder again clears the previous error',
      (tester) async {
    await atMinimumWindowSize(tester);
    await tester.pumpWidget(wrap(
      (_) {},
      access: _FakeAccess(unwritable: {'/sorted'}),
    ));

    await chooseSource(tester, '/photos');
    await addDestination(tester, 'Family', '/sorted');
    await tester.tap(find.text('Start sorting'));
    await tester.pumpAndSettle();
    expect(find.textContaining('cannot be written to'), findsOneWidget);

    await chooseSource(tester, '/photos');

    expect(find.textContaining('cannot be written to'), findsNothing);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
