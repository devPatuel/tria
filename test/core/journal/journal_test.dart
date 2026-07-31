import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tria/core/journal/journal.dart';
import 'package:tria/domain/decision.dart';
import 'package:tria/domain/journal_entry.dart';

void main() {
  late Directory tmp;
  late JsonlJournal journal;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('tria_journal_');
    journal = JsonlJournal(File('${tmp.path}/journal.jsonl'));
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  JournalEntry entry(String id, OperationStatus status) => JournalEntry(
        id: id,
        sessionId: 's1',
        kind: DecisionKind.move,
        sourcePath: '/photos/$id.jpg',
        actualTargetPath: '/family/$id.jpg',
        status: status,
        timestamp: DateTime.utc(2026, 7, 30),
      );

  test('appends and reads back entries in order', () async {
    await journal.append(entry('a', OperationStatus.pending));
    await journal.append(entry('b', OperationStatus.pending));

    final all = await journal.readAll();
    expect(all.map((e) => e.id), ['a', 'b']);
  });

  test('survives a round trip through JSON without losing fields', () async {
    await journal.append(entry('a', OperationStatus.done));

    final read = (await journal.readAll()).single;
    expect(read.sourcePath, '/photos/a.jpg');
    expect(read.actualTargetPath, '/family/a.jpg');
    expect(read.kind, DecisionKind.move);
    expect(read.status, OperationStatus.done);
    expect(read.timestamp, DateTime.utc(2026, 7, 30));
  });

  test('an entry updated to done is no longer pending', () async {
    await journal.append(entry('a', OperationStatus.pending));
    await journal.append(entry('a', OperationStatus.done));

    expect(await journal.pending(), isEmpty);
    expect((await journal.completedInOrder()).single.id, 'a');
  });

  test('reports entries left pending by an unexpected shutdown', () async {
    await journal.append(entry('a', OperationStatus.pending));
    await journal.append(entry('b', OperationStatus.pending));
    await journal.append(entry('b', OperationStatus.done));

    expect((await journal.pending()).map((e) => e.id), ['a']);
  });

  test('reading a missing journal file yields no entries', () async {
    final absent = JsonlJournal(File('${tmp.path}/nope.jsonl'));
    expect(await absent.readAll(), isEmpty);
  });

  test('ignores a truncated final line instead of failing', () async {
    final file = File('${tmp.path}/journal.jsonl');
    await journal.append(entry('a', OperationStatus.done));
    await file.writeAsString('{"id":"b","sessi', mode: FileMode.append);

    expect((await journal.readAll()).map((e) => e.id), ['a']);
  });
}
