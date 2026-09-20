import 'dart:io';

import 'package:path/path.dart' as p;

import '../../domain/file_entry.dart';

/// Walks the source folder and emits files as it finds them.
///
/// Results are streamed rather than collected so the user can start sorting
/// the first file while a folder with tens of thousands of entries is still
/// being walked.
class FileScanner {
  Stream<FileEntry> scan(
    String root, {
    bool recursive = true,
    String? excludeFolder,
  }) async* {
    final dir = Directory(root);
    if (!await dir.exists()) return;

    await for (final entity in dir.list(recursive: recursive, followLinks: false)) {
      if (entity is! File) continue;

      final relative = p.relative(entity.path, from: root);
      if (excludeFolder != null && p.split(relative).contains(excludeFolder)) {
        continue;
      }

      final name = p.basename(entity.path);
      if (name == '.DS_Store') continue;
      // macOS stores the metadata of every file it touches on exFAT or NTFS in
      // a sidecar named `._name`, so a folder used on an external drive holds
      // one of these per real file. They are not the user's files to sort.
      if (name.startsWith('._')) continue;

      final stat = await entity.stat();
      yield FileEntry(
        path: entity.path,
        sizeBytes: stat.size,
        modifiedAt: stat.modified,
        isCloudPlaceholder: _isCloudPlaceholder(name, stat.size),
      );
    }
  }

  /// Detects files that live in the cloud rather than on this disk.
  ///
  /// iCloud replaces an evicted file with a hidden `.name.ext.icloud` stub;
  /// OneDrive leaves a zero-length file. Both would render as a broken preview
  /// if treated as ordinary files.
  bool _isCloudPlaceholder(String name, int size) {
    if (name.startsWith('.') && name.endsWith('.icloud')) return true;
    return size == 0;
  }
}
