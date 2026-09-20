import 'dart:io';

import 'package:path/path.dart' as p;

/// Answers whether Tría can really write to a folder.
///
/// Asking the file system for permission bits is not enough: a drive mounted
/// read-only (macOS does this to every NTFS volume) reports ordinary
/// permissions and still refuses every write. The only reliable answer is to
/// write something and see what happens, which is why this probes with a real
/// file and removes it again.
class FolderAccess {
  Future<bool> isWritable(String path) async {
    final dir = Directory(path);
    try {
      if (!await dir.exists()) {
        // A destination that does not exist yet is fine as long as it can be
        // created, which is exactly what the session would do on first use.
        if (File(path).existsSync()) return false;
        await dir.create(recursive: true);
      }
      final probe = File(p.join(path, '.tria-write-check'));
      await probe.writeAsString('');
      await probe.delete();
      return true;
    } on FileSystemException {
      return false;
    }
  }
}
