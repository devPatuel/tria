/// What the user pressed for a given file.
enum DecisionKind {
  /// Sent to one of the numbered destinations.
  move,

  /// Sent to the soft trash.
  trash,

  /// Deferred: asked again at the end of the session.
  postpone,

  /// Deliberately left where it is; not asked again.
  keep,
}

/// A single user decision, before it has been carried out.
class Decision {
  final DecisionKind kind;
  final String sourcePath;

  /// Destination slot; only meaningful when [kind] is [DecisionKind.move].
  final int? slot;

  const Decision({required this.kind, required this.sourcePath, this.slot});
}
