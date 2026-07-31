import 'dart:io';

import 'package:path/path.dart' as p;

import 'move_result.dart';

/// Moves files without ever destroying data.
///
/// Two rules drive every branch here: an existing file is never overwritten,
/// and the source is only removed once the copy is known to be intact.
class FileMover {
  /// Moves [sourcePath] into [targetDir], creating the folder if needed.
  Future<MoveResult> move(String sourcePath, String targetDir) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      return const MoveResult.failure(MoveError.sourceMissing);
    }

    try {
      await Directory(targetDir).create(recursive: true);
    } on FileSystemException {
      return const MoveResult.failure(MoveError.destinationNotWritable);
    }

    final targetPath = resolveCollision(targetDir, p.basename(sourcePath));

    try {
      await source.rename(targetPath);
      return MoveResult.success(targetPath);
    } on FileSystemException {
      // rename() fails across volumes: fall back to copy + verify + delete.
      return _copyVerifyDelete(source, targetPath);
    }
  }

  /// Returns a free path inside [targetDir] for [fileName], adding ` (n)`
  /// before the extension when the name is taken.
  String resolveCollision(String targetDir, String fileName) {
    final candidate = p.join(targetDir, fileName);
    if (!File(candidate).existsSync()) return candidate;

    final stem = p.basenameWithoutExtension(fileName);
    final ext = p.extension(fileName);
    var counter = 2;
    while (true) {
      final next = p.join(targetDir, '$stem ($counter)$ext');
      if (!File(next).existsSync()) return next;
      counter++;
    }
  }

  Future<MoveResult> _copyVerifyDelete(File source, String targetPath) async {
    try {
      final sourceLength = await source.length();
      final modified = await source.lastModified();

      final copy = await source.copy(targetPath);
      if (await copy.length() != sourceLength) {
        await copy.delete();
        return const MoveResult.failure(MoveError.verificationFailed);
      }
      await copy.setLastModified(modified);

      await source.delete();
      return MoveResult.success(targetPath);
    } on FileSystemException catch (e) {
      // ENOSPC is 28 on both macOS and Windows' POSIX layer.
      if (e.osError?.errorCode == 28) {
        return const MoveResult.failure(MoveError.diskFull);
      }
      return const MoveResult.failure(MoveError.unknown);
    }
  }
}
