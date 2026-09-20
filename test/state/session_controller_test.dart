import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tria/core/fs/file_mover.dart';
import 'package:tria/core/fs/operation_queue.dart';
import 'package:tria/core/fs/reverter.dart';
import 'package:tria/core/fs/soft_trash.dart';
import 'package:tria/core/journal/journal.dart';
import 'package:tria/core/scanner/file_scanner.dart';
import 'package:tria/domain/decision.dart';
import 'package:tria/domain/destination.dart';
import 'package:tria/domain/session_config.dart';
import 'package:tria/state/session_controller.dart';

import '../support/fixtures.dart';

void main() {
  late Directory tmp;
  late Directory source;
  late SessionController controller;
  late SessionConfig config;
  late OperationQueue queue;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('tria_controller_');
    source = Directory('${tmp.path}/source')..createSync();
    writeFakeImage(source, 'a.jpg');
    writeFakeImage(source, 'b.jpg');
    writeFakeImage(source, 'c.jpg');

    config = SessionConfig(
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
  });

  // The queue keeps working after a decision returns — that is the whole point
  // of it. Deleting the folder before it drains would fail the test for a
  // reason that has nothing to do with what it asserts.
  tearDown(() async {
    await queue.drain();
    tmp.deleteSync(recursive: true);
  });

  test('starts on the first file with the full count known', () {
    expect(controller.current, isNotNull);
    expect(controller.totalCount, 3);
    expect(controller.decidedCount, 0);
  });

  test('deciding advances to the next file immediately', () {
    final first = controller.current!.path;

    controller.decide(Decision(kind: DecisionKind.move, sourcePath: first, slot: 1));

    expect(controller.current!.path, isNot(first));
    expect(controller.decidedCount, 1);
  });

  test('postponed files are collected instead of decided', () {
    controller.decide(Decision(
      kind: DecisionKind.postpone,
      sourcePath: controller.current!.path,
    ));

    expect(controller.postponed.length, 1);
  });

  test('the session finishes when every file has been decided', () {
    for (var i = 0; i < 3; i++) {
      controller.decide(Decision(
        kind: DecisionKind.keep,
        sourcePath: controller.current!.path,
      ));
    }

    expect(controller.isFinished, isTrue);
    expect(controller.current, isNull);
  });

  test('a postponed round re-asks only the postponed files', () async {
    final first = controller.current!.path;
    controller.decide(Decision(kind: DecisionKind.postpone, sourcePath: first));
    controller.decide(Decision(
        kind: DecisionKind.keep, sourcePath: controller.current!.path));
    controller.decide(Decision(
        kind: DecisionKind.keep, sourcePath: controller.current!.path));

    await controller.startPostponedRound();

    expect(controller.isFinished, isFalse);
    expect(controller.current!.path, first);
  });

  test('undo steps back to the previous file', () async {
    final first = controller.current!.path;
    controller.decide(Decision(kind: DecisionKind.move, sourcePath: first, slot: 1));

    await controller.undo();

    expect(controller.current!.path, first);
    expect(controller.decidedCount, 0);
  });

  test('notifies listeners on every decision', () {
    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.decide(Decision(
      kind: DecisionKind.keep,
      sourcePath: controller.current!.path,
    ));

    expect(notifications, greaterThan(0));
  });

  test('a move that fails is surfaced instead of being swallowed', () async {
    // A file sitting where the destination folder should be makes the move
    // fail the same way a read-only drive does.
    File('${tmp.path}/blocked').writeAsStringSync('not a folder');
    final blockedConfig = SessionConfig(
      id: 's2',
      sourceRoot: source.path,
      recursive: true,
      destinations: [
        Destination(slot: 1, label: 'Family', path: '${tmp.path}/blocked/family'),
      ],
    );
    final journal = JsonlJournal(File('${tmp.path}/journal2.jsonl'));
    final mover = FileMover();
    final blockedQueue = OperationQueue(
      config: blockedConfig,
      journal: journal,
      mover: mover,
      trash: SoftTrash(blockedConfig.trashPath, mover),
    );
    final blocked = SessionController(
      config: blockedConfig,
      queue: blockedQueue,
      reverter: Reverter(journal, mover),
      scanner: FileScanner(),
    );
    await blocked.start();
    var notified = 0;
    blocked.addListener(() => notified++);

    blocked.decide(Decision(
      kind: DecisionKind.move,
      sourcePath: blocked.current!.path,
      slot: 1,
    ));
    await blockedQueue.drain();
    await Future<void>.delayed(Duration.zero);

    expect(blocked.failures.length, 1);
    expect(blocked.failures.single.kind, DecisionKind.move);
    expect(notified, greaterThan(1), reason: 'the interface must be told');
  });
}
