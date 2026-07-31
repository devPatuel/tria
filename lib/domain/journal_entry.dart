import 'decision.dart';

/// Lifecycle of a single file operation.
enum OperationStatus { pending, done, failed, reverted }

/// One line of the journal: an intent, and later its outcome.
///
/// Entries are never mutated in place. A new entry with the same [id] and a
/// different [status] supersedes the previous one, which is what makes the
/// file append-only and therefore crash-safe.
class JournalEntry {
  final String id;
  final String sessionId;
  final DecisionKind kind;
  final String sourcePath;

  /// Where the file actually ended up.
  ///
  /// May differ from the requested folder when a name collision forced a
  /// suffix; undo relies on this value, never on the requested path.
  final String? actualTargetPath;

  final OperationStatus status;
  final DateTime timestamp;
  final String? errorMessage;

  const JournalEntry({
    required this.id,
    required this.sessionId,
    required this.kind,
    required this.sourcePath,
    required this.status,
    required this.timestamp,
    this.actualTargetPath,
    this.errorMessage,
  });

  JournalEntry copyWith({
    OperationStatus? status,
    String? actualTargetPath,
    String? errorMessage,
  }) {
    return JournalEntry(
      id: id,
      sessionId: sessionId,
      kind: kind,
      sourcePath: sourcePath,
      status: status ?? this.status,
      timestamp: timestamp,
      actualTargetPath: actualTargetPath ?? this.actualTargetPath,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sessionId': sessionId,
        'kind': kind.name,
        'sourcePath': sourcePath,
        'actualTargetPath': actualTargetPath,
        'status': status.name,
        'timestamp': timestamp.toIso8601String(),
        'errorMessage': errorMessage,
      };

  factory JournalEntry.fromJson(Map<String, dynamic> json) => JournalEntry(
        id: json['id'] as String,
        sessionId: json['sessionId'] as String,
        kind: DecisionKind.values.byName(json['kind'] as String),
        sourcePath: json['sourcePath'] as String,
        actualTargetPath: json['actualTargetPath'] as String?,
        status: OperationStatus.values.byName(json['status'] as String),
        timestamp: DateTime.parse(json['timestamp'] as String),
        errorMessage: json['errorMessage'] as String?,
      );
}
