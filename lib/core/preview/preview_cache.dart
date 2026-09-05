import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

/// Small LRU cache of file bytes, filled ahead of the user.
///
/// Reading and decoding is the only slow step in a decision loop that must
/// stay under 16 ms. Doing it for the next few files while the current one is
/// still on screen makes the wait disappear.
class PreviewCache {
  final int capacity;
  final LinkedHashMap<String, Uint8List> _entries = LinkedHashMap();

  PreviewCache({this.capacity = 8});

  int get size => _entries.length;

  /// Returns the bytes of [path], from cache when possible.
  ///
  /// A file that disappeared mid-session yields null rather than throwing:
  /// another program moving a file is routine, not an error worth stopping for.
  Future<Uint8List?> load(String path) async {
    final cached = _entries.remove(path);
    if (cached != null) {
      _entries[path] = cached; // Reinsert to mark as most recently used.
      return cached;
    }

    final file = File(path);
    if (!await file.exists()) return null;

    final bytes = await file.readAsBytes();
    _put(path, bytes);
    return bytes;
  }

  /// Reads at most [maxBytes] from the start of [path], without caching.
  ///
  /// Text previews only ever show the first screenful, and some of the files
  /// being sorted are logs or dumps measured in hundreds of megabytes. Reading
  /// the whole thing to display sixty lines would trade the user's memory for
  /// nothing.
  Future<Uint8List?> loadHead(String path, {int maxBytes = 64 * 1024}) async {
    final file = File(path);
    if (!await file.exists()) return null;

    final handle = await file.open();
    try {
      return await handle.read(maxBytes);
    } finally {
      await handle.close();
    }
  }

  /// Warms the cache for the files the user is about to see.
  void preload(Iterable<String> paths) {
    for (final path in paths) {
      if (_entries.containsKey(path)) continue;
      unawaited(load(path));
    }
  }

  void clear() => _entries.clear();

  void _put(String path, Uint8List bytes) {
    _entries[path] = bytes;
    while (_entries.length > capacity) {
      _entries.remove(_entries.keys.first);
    }
  }
}
