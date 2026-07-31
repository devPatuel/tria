import 'package:path/path.dart' as p;

import '../../domain/journal_entry.dart';
import '../journal/journal.dart';
import 'file_mover.dart';

/// Puts files back where they came from, using the journal as the only source
/// of truth.
///
/// Every revert is itself recorded, so the journal remains a complete history
/// and an entry can never be reverted twice.
class Reverter {
  final JsonlJournal journal;
  final FileMover mover;

  Reverter(this.journal, this.mover);

  /// Reverts the most recent completed operation. Returns the entry that was
  /// undone, or null when there is nothing left.
  Future<JournalEntry?> undoLast() async {
    final completed = await journal.completedInOrder();
    if (completed.isEmpty) return null;
    return _revert(completed.last);
  }

  /// Reverts every completed operation of [sessionId], newest first, and
  /// returns how many were undone.
  ///
  /// Newest first matters: reverting in reverse order restores files into
  /// folders that still exist and avoids re-creating a collision that a later
  /// operation had already resolved.
  Future<int> revertSession(String sessionId) async {
    final completed = (await journal.completedInOrder())
        .where((e) => e.sessionId == sessionId)
        .toList()
        .reversed
        .toList();

    var count = 0;
    for (final entry in completed) {
      if (await _revert(entry) != null) count++;
    }
    return count;
  }

  Future<JournalEntry?> _revert(JournalEntry entry) async {
    final current = entry.actualTargetPath;
    if (current == null) return null;

    final result = await mover.move(current, p.dirname(entry.sourcePath));
    if (!result.ok) {
      await journal.append(entry.copyWith(
        status: OperationStatus.failed,
        errorMessage: 'revert failed: ${result.error?.name}',
      ));
      return null;
    }

    await journal.append(entry.copyWith(status: OperationStatus.reverted));
    return entry;
  }
}
