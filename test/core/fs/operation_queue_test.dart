import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tria/core/fs/file_mover.dart';
import 'package:tria/core/fs/operation_queue.dart';
import 'package:tria/core/fs/soft_trash.dart';
import 'package:tria/core/journal/journal.dart';
import 'package:tria/domain/decision.dart';
import 'package:tria/domain/destination.dart';
import 'package:tria/domain/journal_entry.dart';
import 'package:tria/domain/session_config.dart';

import '../../support/fixtures.dart';

void main() {
  late Directory tmp;
  late Directory source;
  late JsonlJournal journal;
  late OperationQueue queue;
  late SessionConfig config;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('tria_queue_');
    source = Directory('${tmp.path}/source')..createSync();
    config = SessionConfig(
      id: 's1',
      sourceRoot: source.path,
      recursive: true,
      destinations: [
        Destination(slot: 1, label: 'Family', path: '${tmp.path}/family'),
      ],
    );
    journal = JsonlJournal(File('${tmp.path}/journal.jsonl'));
    final mover = FileMover();
    queue = OperationQueue(
      config: config,
      journal: journal,
      mover: mover,
      trash: SoftTrash(config.trashPath, mover),
    );
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  test('a move decision ends with the file in the destination', () async {
    writeFakeImage(source, 'a.jpg');

    queue.enqueue(Decision(
      kind: DecisionKind.move,
      sourcePath: '${source.path}/a.jpg',
      slot: 1,
    ));
    await queue.drain();

    expect(File('${tmp.path}/family/a.jpg').existsSync(), isTrue);
  });

  test('writes pending before the operation and done after it', () async {
    writeFakeImage(source, 'a.jpg');

    queue.enqueue(Decision(
      kind: DecisionKind.move,
      sourcePath: '${source.path}/a.jpg',
      slot: 1,
    ));
    await queue.drain();

    final statuses = (await journal.readAll()).map((e) => e.status).toList();
    expect(statuses, [OperationStatus.pending, OperationStatus.done]);
  });

  test('a trash decision moves the file to the soft trash', () async {
    writeFakeImage(source, 'meme.jpg');

    queue.enqueue(Decision(
      kind: DecisionKind.trash,
      sourcePath: '${source.path}/meme.jpg',
    ));
    await queue.drain();

    expect(File('${config.trashPath}/meme.jpg').existsSync(), isTrue);
  });

  test('keep and postpone touch no files and write no journal entries', () async {
    writeFakeImage(source, 'a.jpg');

    queue.enqueue(Decision(kind: DecisionKind.keep, sourcePath: '${source.path}/a.jpg'));
    queue.enqueue(
        Decision(kind: DecisionKind.postpone, sourcePath: '${source.path}/a.jpg'));
    await queue.drain();

    expect(File('${source.path}/a.jpg').existsSync(), isTrue);
    expect(await journal.readAll(), isEmpty);
  });

  test('a failed operation is reported and does not stop the queue', () async {
    writeFakeImage(source, 'b.jpg');

    final reported = <JournalEntry>[];
    queue.failures.listen(reported.add);

    queue.enqueue(Decision(
      kind: DecisionKind.move,
      sourcePath: '${source.path}/ghost.jpg',
      slot: 1,
    ));
    queue.enqueue(Decision(
      kind: DecisionKind.move,
      sourcePath: '${source.path}/b.jpg',
      slot: 1,
    ));
    await queue.drain();

    expect(File('${tmp.path}/family/b.jpg').existsSync(), isTrue,
        reason: 'one bad file must not block the rest of the session');
    expect(reported.single.sourcePath, endsWith('ghost.jpg'));
  });

  test('records the real target path when a name collides', () async {
    writeFakeImage(source, 'a.jpg');
    writeFakeImage(Directory('${tmp.path}/family')..createSync(), 'a.jpg');

    queue.enqueue(Decision(
      kind: DecisionKind.move,
      sourcePath: '${source.path}/a.jpg',
      slot: 1,
    ));
    await queue.drain();

    final done = (await journal.completedInOrder()).single;
    expect(done.actualTargetPath, endsWith('a (2).jpg'));
  });
}
