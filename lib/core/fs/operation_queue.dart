import 'dart:async';
import 'dart:collection';

import '../../domain/decision.dart';
import '../../domain/journal_entry.dart';
import '../../domain/session_config.dart';
import '../journal/journal.dart';
import 'file_mover.dart';
import 'soft_trash.dart';

/// Runs file operations one at a time, off the UI's critical path.
///
/// Pressing a key must never wait for the disk: at two decisions per second,
/// the latency of an external drive would destroy the flow the product is
/// built around. Operations are serialised rather than parallelised because
/// concurrent writes to one disk are slower, and because a single ordered
/// journal is what makes undo tractable.
class OperationQueue {
  final SessionConfig config;
  final JsonlJournal journal;
  final FileMover mover;
  final SoftTrash trash;

  final Queue<Decision> _queue = Queue();
  final StreamController<JournalEntry> _failures = StreamController.broadcast();
  Future<void> _chain = Future.value();
  var _counter = 0;

  OperationQueue({
    required this.config,
    required this.journal,
    required this.mover,
    required this.trash,
  });

  /// Operations that could not be completed, for the UI to surface without
  /// interrupting the user.
  Stream<JournalEntry> get failures => _failures.stream;

  int get pendingCount => _queue.length;

  /// Accepts a decision and returns immediately.
  void enqueue(Decision decision) {
    if (decision.kind == DecisionKind.keep ||
        decision.kind == DecisionKind.postpone) {
      return; // Nothing touches the disk, so nothing is journalled.
    }
    _queue.add(decision);
    _chain = _chain.then((_) => _runNext());
  }

  /// Waits until every queued operation has finished.
  Future<void> drain() => _chain;

  Future<void> _runNext() async {
    if (_queue.isEmpty) return;
    final decision = _queue.removeFirst();

    final entry = JournalEntry(
      id: '${config.id}-${_counter++}',
      sessionId: config.id,
      kind: decision.kind,
      sourcePath: decision.sourcePath,
      status: OperationStatus.pending,
      timestamp: DateTime.now(),
    );
    await journal.append(entry);

    final result = switch (decision.kind) {
      DecisionKind.trash => await trash.send(decision.sourcePath),
      DecisionKind.move => await mover.move(
          decision.sourcePath,
          config.destinationForSlot(decision.slot!)!.path,
        ),
      _ => null,
    };

    if (result == null) return;

    if (result.ok) {
      await journal.append(entry.copyWith(
        status: OperationStatus.done,
        actualTargetPath: result.actualPath,
      ));
    } else {
      final failed = entry.copyWith(
        status: OperationStatus.failed,
        errorMessage: result.error?.name,
      );
      await journal.append(failed);
      _failures.add(failed);
    }
  }

  Future<void> dispose() async {
    await drain();
    await _failures.close();
  }
}
