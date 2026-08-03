import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tria/core/fs/file_mover.dart';
import 'package:tria/core/fs/reverter.dart';
import 'package:tria/core/journal/journal.dart';
import 'package:tria/domain/decision.dart';
import 'package:tria/domain/journal_entry.dart';

import '../../support/fixtures.dart';

void main() {
  late Directory tmp;
  late Directory source;
  late Directory family;
  late JsonlJournal journal;
  late Reverter reverter;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('tria_revert_');
    source = Directory('${tmp.path}/source')..createSync();
    family = Directory('${tmp.path}/family')..createSync();
    journal = JsonlJournal(File('${tmp.path}/journal.jsonl'));
    reverter = Reverter(journal, FileMover());
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  /// Performs a real move and records it, the way the controller will.
  Future<void> recordedMove(String id, String name) async {
    writeFakeImage(source, name);
    final result = await FileMover().move('${source.path}/$name', family.path);
    await journal.append(JournalEntry(
      id: id,
      sessionId: 's1',
      kind: DecisionKind.move,
      sourcePath: '${source.path}/$name',
      actualTargetPath: result.actualPath,
      status: OperationStatus.done,
      timestamp: DateTime.utc(2026, 7, 30, 10, int.parse(id)),
    ));
  }

  test('undo puts the last file back where it came from', () async {
    await recordedMove('1', 'a.jpg');

    final undone = await reverter.undoLast();

    expect(undone?.id, '1');
    expect(File('${source.path}/a.jpg').existsSync(), isTrue);
    expect(File('${family.path}/a.jpg').existsSync(), isFalse);
  });

  test('undo walks backwards one file at a time', () async {
    await recordedMove('1', 'a.jpg');
    await recordedMove('2', 'b.jpg');

    await reverter.undoLast();
    expect(File('${source.path}/b.jpg').existsSync(), isTrue);
    expect(File('${family.path}/a.jpg').existsSync(), isTrue);

    await reverter.undoLast();
    expect(File('${source.path}/a.jpg').existsSync(), isTrue);
  });

  test('undo with nothing left to undo returns null', () async {
    expect(await reverter.undoLast(), isNull);
  });

  test('an undone operation is not undone twice', () async {
    await recordedMove('1', 'a.jpg');

    await reverter.undoLast();
    expect(await reverter.undoLast(), isNull);
  });

  test('reverting a session leaves the tree exactly as it was', () async {
    writeFakeImage(source, 'a.jpg');
    writeFakeImage(source, 'b.jpg');
    writeFakeImage(source, 'c.jpg');
    final before = source.listSync().map((e) => e.path).toList()..sort();

    for (final entry in [('1', 'a.jpg'), ('2', 'b.jpg'), ('3', 'c.jpg')]) {
      final result = await FileMover().move('${source.path}/${entry.$2}', family.path);
      await journal.append(JournalEntry(
        id: entry.$1,
        sessionId: 's1',
        kind: DecisionKind.move,
        sourcePath: '${source.path}/${entry.$2}',
        actualTargetPath: result.actualPath,
        status: OperationStatus.done,
        timestamp: DateTime.utc(2026, 7, 30, 10, int.parse(entry.$1)),
      ));
    }
    expect(source.listSync(), isEmpty);

    final reverted = await reverter.revertSession('s1');

    expect(reverted, 3);
    final after = source.listSync().map((e) => e.path).toList()..sort();
    expect(after, before);
    expect(family.listSync(), isEmpty);
  });
}
