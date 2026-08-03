import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../core/fs/operation_queue.dart';
import '../core/fs/reverter.dart';
import '../core/scanner/file_scanner.dart';
import '../domain/decision.dart';
import '../domain/file_entry.dart';
import '../domain/session_config.dart';

/// Drives one sorting session: which file is on screen, what the user decided,
/// and what is left.
///
/// It never waits for the disk. A decision moves the cursor forward at once
/// and hands the work to [OperationQueue]; the flow of the session is the
/// product, and blocking on I/O would destroy it.
class SessionController extends ChangeNotifier {
  final SessionConfig config;
  final OperationQueue queue;
  final Reverter reverter;
  final FileScanner scanner;

  /// Paths already decided in a previous, interrupted run.
  final Set<String> alreadyProcessed;

  final List<FileEntry> _queueOfFiles = [];
  final List<FileEntry> _postponed = [];
  final List<Decision> _history = [];
  var _cursor = 0;

  final Map<int, int> _movedPerSlot = {};
  var _trashedCount = 0;
  var _keptCount = 0;
  var _postponedCount = 0;

  /// When the session began, for reporting duration and throughput.
  final DateTime startedAt = DateTime.now();

  SessionController({
    required this.config,
    required this.queue,
    required this.reverter,
    required this.scanner,
    this.alreadyProcessed = const {},
  }) {
    for (final destination in config.destinations) {
      _movedPerSlot[destination.slot] = 0;
    }
  }

  /// Scans the source folder and positions the cursor on the first file.
  Future<void> start() async {
    final stream = scanner.scan(
      config.sourceRoot,
      recursive: config.recursive,
      // Derived from the config so the folder name lives in exactly one place.
      excludeFolder: p.basename(config.trashPath),
    );
    await for (final entry in stream) {
      if (alreadyProcessed.contains(entry.path)) continue;
      _queueOfFiles.add(entry);
    }
    notifyListeners();
  }

  FileEntry? get current =>
      _cursor < _queueOfFiles.length ? _queueOfFiles[_cursor] : null;

  int get totalCount => _queueOfFiles.length;

  int get decidedCount => _cursor;

  List<FileEntry> get postponed => List.unmodifiable(_postponed);

  /// The file at [index] in the session queue, for lookahead preloading.
  FileEntry fileAt(int index) => _queueOfFiles[index];

  /// How many files have gone to each destination slot so far.
  ///
  /// Every configured slot is present from the start, at zero, so the interface
  /// can render a stable row per destination instead of one that appears on
  /// first use.
  Map<int, int> get movedPerSlot => Map.unmodifiable(_movedPerSlot);

  int get trashedCount => _trashedCount;

  int get keptCount => _keptCount;

  int get postponedCount => _postponedCount;

  Duration get elapsed => DateTime.now().difference(startedAt);

  /// Decisions per second, as a running average over the whole session.
  double get filesPerSecond {
    final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    if (seconds <= 0 || _cursor == 0) return 0;
    return _cursor / seconds;
  }

  void _count(Decision decision, int delta) {
    switch (decision.kind) {
      case DecisionKind.move:
        final slot = decision.slot;
        if (slot != null) {
          _movedPerSlot[slot] = (_movedPerSlot[slot] ?? 0) + delta;
        }
      case DecisionKind.trash:
        _trashedCount += delta;
      case DecisionKind.keep:
        _keptCount += delta;
      case DecisionKind.postpone:
        _postponedCount += delta;
    }
  }

  bool get isFinished => current == null;

  /// Records the decision, hands it to the queue and advances.
  void decide(Decision decision) {
    if (decision.kind == DecisionKind.postpone) {
      final entry = current;
      if (entry != null) _postponed.add(entry);
    }
    _history.add(decision);
    _count(decision, 1);
    queue.enqueue(decision);
    _cursor++;
    notifyListeners();
  }

  /// Undoes the last decision and steps the cursor back.
  Future<void> undo() async {
    if (_history.isEmpty) return;
    final last = _history.removeLast();
    _count(last, -1);

    if (last.kind == DecisionKind.move || last.kind == DecisionKind.trash) {
      await queue.drain();
      await reverter.undoLast();
    }
    if (last.kind == DecisionKind.postpone && _postponed.isNotEmpty) {
      _postponed.removeLast();
    }

    _cursor--;
    notifyListeners();
  }

  /// Re-queues the postponed files for a second pass.
  Future<void> startPostponedRound() async {
    if (_postponed.isEmpty) return;
    _queueOfFiles
      ..clear()
      ..addAll(_postponed);
    _postponed.clear();
    _history.clear();
    _cursor = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    queue.dispose();
    super.dispose();
  }
}
