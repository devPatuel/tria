import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tria/core/journal/journal.dart';
import 'package:tria/core/journal/recovery.dart';
import 'package:tria/domain/decision.dart';
import 'package:tria/domain/journal_entry.dart';

import '../../support/fixtures.dart';

void main() {
  late Directory tmp;
  late Directory source;
  late Directory family;
  late JsonlJournal journal;
  late SessionRecovery recovery;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('tria_recovery_');
    source = Directory('${tmp.path}/source')..createSync();
    family = Directory('${tmp.path}/family')..createSync();
    journal = JsonlJournal(File('${tmp.path}/journal.jsonl'));
    recovery = SessionRecovery(journal);
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  JournalEntry pendingEntry(String id, String name) => JournalEntry(
        id: id,
        sessionId: 's1',
        kind: DecisionKind.move,
        sourcePath: '${source.path}/$name',
        actualTargetPath: '${family.path}/$name',
        status: OperationStatus.pending,
        timestamp: DateTime.utc(2026, 7, 30),
      );

  test('a pending move that actually landed is marked done', () async {
    writeFakeImage(family, 'a.jpg'); // it did happen before the crash
    await journal.append(pendingEntry('1', 'a.jpg'));

    final report = await recovery.recover();

    expect(report.repaired.single.id, '1');
    expect((await journal.completedInOrder()).single.id, '1');
  });

  test('a pending move that never happened is marked failed', () async {
    writeFakeImage(source, 'a.jpg'); // still at the source
    await journal.append(pendingEntry('1', 'a.jpg'));

    final report = await recovery.recover();

    expect(report.lost.single.id, '1');
    expect(await journal.pending(), isEmpty);
  });

  test('already-completed work is reported so it is not asked again', () async {
    writeFakeImage(family, 'a.jpg');
    await journal.append(pendingEntry('1', 'a.jpg'));
    await journal.append(pendingEntry('1', 'a.jpg')
        .copyWith(status: OperationStatus.done));

    final report = await recovery.recover();

    expect(report.completed.single.id, '1');
    expect(report.processedPaths, contains('${source.path}/a.jpg'));
  });

  test('a clean journal recovers to an empty report', () async {
    final report = await recovery.recover();

    expect(report.completed, isEmpty);
    expect(report.repaired, isEmpty);
    expect(report.lost, isEmpty);
  });
}
