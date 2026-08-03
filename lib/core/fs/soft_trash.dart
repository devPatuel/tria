import 'dart:io';

import 'file_mover.dart';
import 'move_result.dart';

/// Holding area for files the user marked as unwanted.
///
/// Deleting in Tría means moving here. Emptying this folder is the only
/// irreversible action in the whole application, which is why it is a separate
/// explicit call and never happens as a side effect.
class SoftTrash {
  final String trashPath;
  final FileMover mover;

  SoftTrash(this.trashPath, this.mover);

  Future<MoveResult> send(String sourcePath) => mover.move(sourcePath, trashPath);

  Future<int> count() async {
    final dir = Directory(trashPath);
    if (!await dir.exists()) return 0;
    return dir.listSync().whereType<File>().length;
  }

  /// Permanently deletes everything in the trash and returns the count.
  Future<int> empty() async {
    final dir = Directory(trashPath);
    if (!await dir.exists()) return 0;
    final files = dir.listSync().whereType<File>().toList();
    for (final file in files) {
      await file.delete();
    }
    return files.length;
  }
}
