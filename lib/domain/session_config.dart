import 'package:path/path.dart' as p;

import 'destination.dart';

/// Everything the user chose before starting to sort: where to read from,
/// whether to descend into subfolders, and where each number key sends files.
///
/// Reusable as a named profile, so returning to the same folder does not mean
/// configuring destinations again.
class SessionConfig {
  final String id;
  final String sourceRoot;
  final bool recursive;
  final List<Destination> destinations;

  SessionConfig({
    required this.id,
    required this.sourceRoot,
    required this.recursive,
    required this.destinations,
  }) {
    final slots = destinations.map((d) => d.slot).toList();
    if (slots.toSet().length != slots.length) {
      throw ArgumentError('two destinations share the same slot');
    }
  }

  /// Soft trash folder, always inside the source root.
  ///
  /// The system trash is deliberately avoided: its behaviour differs between
  /// platforms and it hides the files from the user, which is the opposite of
  /// what a reversible tool should do.
  String get trashPath => p.join(sourceRoot, '_trash');

  Destination? destinationForSlot(int slot) {
    for (final d in destinations) {
      if (d.slot == slot) return d;
    }
    return null;
  }
}
