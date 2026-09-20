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
      // Note this succeeds on a folder that already exists even when it is
      // read-only, so it catches a missing parent, never a locked target.
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
    final File copy;
    final int sourceLength;
    final DateTime modified;
    try {
      sourceLength = await source.length();
      modified = await source.lastModified();
      copy = await source.copy(targetPath);
    } on FileSystemException catch (e) {
      // Writing into the destination is where a locked drive shows itself, so
      // this failure is classified apart: telling the user which end of the
      // move refused them is the difference between a fixable problem and a
      // shrug.
      return MoveResult.failure(_writeError(e));
    }

    try {
      if (await copy.length() != sourceLength) {
        await copy.delete();
        return const MoveResult.failure(MoveError.verificationFailed);
      }
      await copy.setLastModified(modified);

      await source.delete();
      return MoveResult.success(targetPath);
    } on FileSystemException catch (e) {
      return MoveResult.failure(_writeError(e));
    }
  }

  /// Reads the operating system's own error code.
  ///
  /// The numbers are the platforms' own: POSIX errno on macOS, Win32 error
  /// codes on Windows, which overlap numerically and must not be mixed.
  MoveError _writeError(FileSystemException e) {
    final code = e.osError?.errorCode;
    if (code == null) return MoveError.unknown;
    if (Platform.isWindows) {
      // ERROR_ACCESS_DENIED, ERROR_WRITE_PROTECT, ERROR_DISK_FULL.
      if (code == 5 || code == 19) return MoveError.destinationNotWritable;
      if (code == 112) return MoveError.diskFull;
      return MoveError.unknown;
    }
    // EPERM, EACCES, EROFS, ENOSPC.
    if (code == 1 || code == 13 || code == 30) {
      return MoveError.destinationNotWritable;
    }
    if (code == 28) return MoveError.diskFull;
    return MoveError.unknown;
  }
}
