import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tria/core/fs/file_mover.dart';
import 'package:tria/core/fs/operation_queue.dart';
import 'package:tria/core/fs/reverter.dart';
import 'package:tria/core/fs/soft_trash.dart';
import 'package:tria/core/preview/preview_cache.dart';
import 'package:tria/core/journal/journal.dart';
import 'package:tria/core/scanner/file_scanner.dart';
import 'package:tria/domain/decision.dart';
import 'package:tria/domain/destination.dart';
import 'package:tria/domain/journal_entry.dart';
import 'package:tria/domain/session_config.dart';
import 'package:tria/state/session_controller.dart';
import 'package:tria/ui/triage_screen.dart';
import 'package:tria/ui/widgets/file_meta.dart';

import '../support/fixtures.dart';

/// Widget tests run on a fake clock where real file reads never complete, and
/// the cache already has its own tests. This keeps the screen tests about the
/// screen.
class _NoDiskCache extends PreviewCache {
  @override
  Future<Uint8List?> load(String path) async => null;

  @override
  void preload(Iterable<String> paths) {}
}

/// A session that has already had an operation refused by the disk. Whether
/// the controller really hears the queue is covered by its own test.
class _ControllerWithFailure extends SessionController {
  _ControllerWithFailure({
    required super.config,
    required super.queue,
    required super.reverter,
    required super.scanner,
  });

  @override
  List<JournalEntry> get failures => [
        JournalEntry(
          id: 's1-0',
          sessionId: 's1',
          kind: DecisionKind.move,
          sourcePath: '/source/a.jpg',
          status: OperationStatus.failed,
          timestamp: DateTime(2026, 9, 20),
          errorMessage: 'destinationNotWritable',
        ),
      ];
}

void main() {
  late Directory tmp;
  late SessionController controller;
  late SessionController failing;
  late OperationQueue queue;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('tria_ui_');
    final source = Directory('${tmp.path}/source')..createSync();
    writeFakeImage(source, 'a.jpg');
    writeFakeImage(source, 'b.jpg');

    final config = SessionConfig(
      id: 's1',
      sourceRoot: source.path,
      recursive: true,
      destinations: [
        Destination(slot: 1, label: 'Family', path: '${tmp.path}/family'),
      ],
    );
    final journal = JsonlJournal(File('${tmp.path}/journal.jsonl'));
    final mover = FileMover();
    queue = OperationQueue(
      config: config,
      journal: journal,
      mover: mover,
      trash: SoftTrash(config.trashPath, mover),
    );
    controller = SessionController(
      config: config,
      queue: queue,
      reverter: Reverter(journal, mover),
      scanner: FileScanner(),
    );
    await controller.start();

    failing = _ControllerWithFailure(
      config: config,
      queue: queue,
      reverter: Reverter(journal, mover),
      scanner: FileScanner(),
    );
    await failing.start();
  });

  tearDown(() {
    try {
      tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows refuses to delete a file that is still open, and the move that
      // 'pressing 1' queues is deliberately never awaited (see that test), so
      // its journal handle can outlive the test. A leftover temp folder is
      // harmless; failing the suite over it is not.
    }
  });

  Widget wrap({VoidCallback? onFinish}) => MaterialApp(
        home: ChangeNotifierProvider.value(
          value: controller,
          child: TriageScreen(cache: _NoDiskCache(), onFinish: onFinish),
        ),
      );

  testWidgets('shows the destination labels and the progress counter',
      (tester) async {
    await tester.pumpWidget(wrap());

    expect(find.text('Family'), findsOneWidget);
    expect(find.text('0/2'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('pressing 1 advances the counter', (tester) async {
    await tester.pumpWidget(wrap());

    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.pump();

    expect(find.text('1/2'), findsOneWidget);
    // The queued move is deliberately not awaited here: widget tests run on a
    // fake clock where it never progresses, and awaiting it through
    // tester.runAsync deadlocks. What the move does on disk is covered by the
    // operation queue's own tests.
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('shows the finished state when nothing is left', (tester) async {
    await tester.pumpWidget(wrap());

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(find.text('Session finished'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('shows the size and date of the current file', (tester) async {
    await tester.pumpWidget(wrap());

    expect(find.byType(FileMeta), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('the destination count goes up as files are sent there',
      (tester) async {
    await tester.pumpWidget(wrap());

    // Keyed because the tile shows two numbers: the key and the count.
    String countOfSlotOne() =>
        tester.widget<Text>(find.byKey(const Key('count-1'))).data!;

    expect(countOfSlotOne(), '0');

    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.pump();

    expect(countOfSlotOne(), '1');
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('keeps the key legend on screen', (tester) async {
    await tester.pumpWidget(wrap());

    expect(find.text('undo'), findsOneWidget);
    expect(find.text('trash'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('Esc ends the session early', (tester) async {
    var finished = false;
    await tester.pumpWidget(wrap(onFinish: () => finished = true));

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(finished, isTrue,
        reason: 'nobody sorts 30,000 files in one sitting');
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('the finish button ends the session early', (tester) async {
    var finished = false;
    await tester.pumpWidget(wrap(onFinish: () => finished = true));

    await tester.tap(find.byKey(const Key('finish-session')));
    await tester.pump();

    expect(finished, isTrue);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('Esc decides nothing on its way out', (tester) async {
    await tester.pumpWidget(wrap(onFinish: () {}));

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(find.text('0/2'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('two keystrokes inside one animation both land', (tester) async {
    await tester.pumpWidget(wrap());

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 20)); // mid-animation
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    // Both files are gone, so the session is over — which is itself the proof
    // that the second keystroke was not swallowed by the running animation.
    expect(find.text('2 files decided'), findsOneWidget,
        reason: 'the animation must never gate a decision');
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('a session with nothing refused shows no warning', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pump();

    expect(find.byKey(const Key('failure-banner')), findsNothing);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('warns during the session when the disk refuses a file',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ChangeNotifierProvider.value(
        value: failing,
        child: TriageScreen(cache: _NoDiskCache()),
      ),
    ));
    await tester.pump();

    expect(find.byKey(const Key('failure-banner')), findsOneWidget);
    expect(find.textContaining('1 file could not be moved'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
