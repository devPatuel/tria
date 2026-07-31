/// Why a move could not be completed.
enum MoveError {
  sourceMissing,
  destinationNotWritable,
  diskFull,
  verificationFailed,
  unknown,
}

/// Outcome of a single move.
///
/// [actualPath] is the path the file really ended up at, which may carry a
/// collision suffix. Undo must use this value.
class MoveResult {
  final bool ok;
  final String? actualPath;
  final MoveError? error;

  const MoveResult.success(String this.actualPath)
      : ok = true,
        error = null;

  const MoveResult.failure(MoveError this.error)
      : ok = false,
        actualPath = null;
}
