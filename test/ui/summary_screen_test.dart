import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tria/core/fs/file_mover.dart';
import 'package:tria/core/fs/reverter.dart';
import 'package:tria/core/fs/soft_trash.dart';
import 'package:tria/core/journal/journal.dart';
import 'package:tria/core/platform/folder_opener.dart';
import 'package:tria/domain/destination.dart';
import 'package:tria/ui/summary_screen.dart';

import 'dart:io';

/// Widget tests run on a fake clock where real file operations never complete,
/// so the screen is tested against doubles. That the trash really deletes is
/// covered by `test/core/fs/soft_trash_test.dart`.
class _FakeTrash extends SoftTrash {
  _FakeTrash() : super('/nowhere', FileMover());

  int _count = 3;
  var emptied = false;

  @override
  Future<int> count() async => _count;

  @override
  Future<int> empty() async {
    emptied = true;
    final deleted = _count;
    _count = 0;
    return deleted;
  }
}

class _FakeReverter extends Reverter {
  _FakeReverter() : super(JsonlJournal(File('/nowhere')), FileMover());

  var revertedSession = false;

  @override
  Future<int> revertSession(String sessionId) async {
    revertedSession = true;
    return 7;
  }
}

/// Records what would have been opened, without opening anything.
class _FakeOpener extends FolderOpener {
  final revealed = <String>[];

  @override
  Future<bool> reveal(String path) async {
    revealed.add(path);
    return true;
  }
}

void main() {
  late _FakeTrash trash;
  late _FakeReverter reverter;
  late _FakeOpener opener;

  setUp(() {
    trash = _FakeTrash();
    reverter = _FakeReverter();
    opener = _FakeOpener();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SummaryScreen(
        trash: trash,
        reverter: reverter,
        sessionId: 's1',
        opener: opener,
        destinations: [
          Destination(slot: 1, label: 'Family', path: '/sorted/family'),
          Destination(slot: 2, label: 'Trips', path: '/sorted/trips'),
        ],
        movedPerSlot: const {1: 12, 2: 5},
        keptCount: 3,
        decidedCount: 20,
        elapsed: const Duration(seconds: 40),
      ),
    ));
    await tester.pump(); // lets the initial count settle
  }

  testWidgets('shows how much is waiting in the trash', (tester) async {
    await pumpScreen(tester);

    final trashRow = tester.widget<DestinationTotalRow>(
        find.widgetWithText(DestinationTotalRow, 'Trash'));
    expect(trashRow.count, 3);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('lists a total per destination', (tester) async {
    await pumpScreen(tester);

    final family = tester.widget<DestinationTotalRow>(
        find.widgetWithText(DestinationTotalRow, 'Family'));
    expect(family.count, 12);
    expect(find.text('Trips'), findsOneWidget);
    expect(find.text('Left in place'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('reports how the session went', (tester) async {
    await pumpScreen(tester);

    expect(find.text('20 files · 40 s · 0.5/s'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('opening a folder asks the system to reveal it', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const Key('open-folder-1')));
    await tester.pumpAndSettle();

    expect(opener.revealed.single, '/sorted/family');
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('emptying the trash asks for confirmation first', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const Key('empty-trash')));
    await tester.pumpAndSettle();

    expect(find.textContaining('cannot be undone'), findsOneWidget);
    expect(trash.emptied, isFalse,
        reason: 'nothing is deleted until the user confirms');
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('cancelling leaves the trash untouched', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const Key('empty-trash')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(trash.emptied, isFalse);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('confirming actually deletes', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const Key('empty-trash')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-empty')));
    await tester.pumpAndSettle();

    expect(trash.emptied, isTrue);
    expect(find.text('Deleted 3 files'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('reverting the session reports what came back', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const Key('revert-session')));
    await tester.pumpAndSettle();

    expect(reverter.revertedSession, isTrue);
    expect(find.text('Put 7 files back where they were'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
