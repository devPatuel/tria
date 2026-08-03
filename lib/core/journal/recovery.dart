import 'dart:io';

import '../../domain/journal_entry.dart';
import 'journal.dart';

/// What a restart found in the journal.
class RecoveryReport {
  /// Operations that had already been confirmed.
  final List<JournalEntry> completed;

  /// Operations left pending that did happen, now confirmed.
  final List<JournalEntry> repaired;

  /// Operations left pending that never happened, now marked failed.
  final List<JournalEntry> lost;

  const RecoveryReport({
    required this.completed,
    required this.repaired,
    required this.lost,
  });

  /// Source paths the user has already decided on, so the session does not ask
  /// about them twice.
  Set<String> get processedPaths =>
      {...completed, ...repaired}.map((e) => e.sourcePath).toSet();
}

/// Reconciles the journal with the disk after an unexpected shutdown.
///
/// A pending entry only says the intent was announced. Whether it happened is
/// a question for the file system, and this is the only place that asks it.
class SessionRecovery {
  final JsonlJournal journal;

  SessionRecovery(this.journal);

  Future<RecoveryReport> recover() async {
    final repaired = <JournalEntry>[];
    final lost = <JournalEntry>[];

    for (final entry in await journal.pending()) {
      final target = entry.actualTargetPath;
      final landed = target != null && await File(target).exists();

      if (landed) {
        final fixed = entry.copyWith(status: OperationStatus.done);
        await journal.append(fixed);
        repaired.add(fixed);
      } else {
        final failed = entry.copyWith(
          status: OperationStatus.failed,
          errorMessage: 'interrupted before completion',
        );
        await journal.append(failed);
        lost.add(failed);
      }
    }

    final completed = (await journal.completedInOrder())
        .where((e) => !repaired.any((r) => r.id == e.id))
        .toList();

    return RecoveryReport(completed: completed, repaired: repaired, lost: lost);
  }
}
