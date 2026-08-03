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
  late SessionController controller;
  late OperationQueue queue;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('tria_stats_');
    final source = Directory('${tmp.path}/source')..createSync();
    for (final name in ['a.jpg', 'b.jpg', 'c.jpg']) {
      writeFakeImage(source, name);
    }

    final config = SessionConfig(
      id: 's1',
      sourceRoot: source.path,
      recursive: true,
      destinations: [
        Destination(slot: 1, label: 'Family', path: '${tmp.path}/family'),
        Destination(slot: 2, label: 'Trips', path: '${tmp.path}/trips'),
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

  tearDown(() async {
    await queue.drain();
    tmp.deleteSync(recursive: true);
  });

  test('counts each decision against its destination', () {
    controller.decide(Decision(
        kind: DecisionKind.move, sourcePath: controller.current!.path, slot: 1));
    controller.decide(Decision(
        kind: DecisionKind.move, sourcePath: controller.current!.path, slot: 1));
    controller.decide(Decision(
        kind: DecisionKind.trash, sourcePath: controller.current!.path));

    expect(controller.movedPerSlot[1], 2);
    expect(controller.movedPerSlot[2], 0);
    expect(controller.trashedCount, 1);
  });

  test('counts keeps and postpones separately', () {
    controller.decide(Decision(
        kind: DecisionKind.keep, sourcePath: controller.current!.path));
    controller.decide(Decision(
        kind: DecisionKind.postpone, sourcePath: controller.current!.path));

    expect(controller.keptCount, 1);
    expect(controller.postponedCount, 1);
  });

  test('undo takes the file back out of the totals', () async {
    controller.decide(Decision(
        kind: DecisionKind.move, sourcePath: controller.current!.path, slot: 1));
    expect(controller.movedPerSlot[1], 1);

    await controller.undo();

    expect(controller.movedPerSlot[1], 0,
        reason: 'a total that survives an undo is a lie');
  });

  test('undoing a trashed file lowers the trash count', () async {
    controller.decide(Decision(
        kind: DecisionKind.trash, sourcePath: controller.current!.path));

    await controller.undo();

    expect(controller.trashedCount, 0);
  });

  test('reports throughput once decisions have been made', () {
    controller.decide(Decision(
        kind: DecisionKind.keep, sourcePath: controller.current!.path));

    expect(controller.elapsed.inMicroseconds, greaterThan(0));
    expect(controller.filesPerSecond, greaterThan(0));
  });

  test('throughput is zero before anything is decided', () {
    expect(controller.filesPerSecond, 0);
  });
}
