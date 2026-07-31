import 'dart:convert';
import 'dart:io';

import '../../domain/journal_entry.dart';

/// Append-only operation log, one JSON object per line.
///
/// This is the single source of truth about what happened on disk. Undo,
/// resume and full-session revert are all reads of this file; the in-memory
/// state is only a cache of it.
class JsonlJournal {
  final File file;

  JsonlJournal(this.file);

  /// Appends [entry] and flushes it before returning.
  ///
  /// The flush is what makes the journal useful: an intent that is still
  /// buffered when the process dies protects nothing.
  Future<void> append(JournalEntry entry) async {
    final sink = file.openWrite(mode: FileMode.append);
    sink.writeln(jsonEncode(entry.toJson()));
    await sink.flush();
    await sink.close();
  }

  /// Reads every entry in write order.
  ///
  /// A malformed trailing line — the signature of a crash mid-write — is
  /// skipped rather than thrown, so a power cut costs one operation, not the
  /// whole session.
  Future<List<JournalEntry>> readAll() async {
    if (!await file.exists()) return [];
    final entries = <JournalEntry>[];
    for (final line in const LineSplitter().convert(await file.readAsString())) {
      if (line.trim().isEmpty) continue;
      try {
        entries.add(JournalEntry.fromJson(jsonDecode(line) as Map<String, dynamic>));
      } on FormatException {
        continue;
      }
    }
    return entries;
  }

  /// Latest state of every operation, keyed by id.
  Future<Map<String, JournalEntry>> _latest() async {
    final byId = <String, JournalEntry>{};
    for (final entry in await readAll()) {
      byId[entry.id] = entry;
    }
    return byId;
  }

  /// Operations that were announced but never resolved — what an unexpected
  /// shutdown leaves behind, and what the app must verify on restart.
  Future<List<JournalEntry>> pending() async {
    final latest = await _latest();
    return latest.values.where((e) => e.status == OperationStatus.pending).toList();
  }

  /// Successfully completed operations, oldest first.
  Future<List<JournalEntry>> completedInOrder() async {
    final latest = await _latest();
    final done = latest.values.where((e) => e.status == OperationStatus.done).toList();
    done.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return done;
  }
}
