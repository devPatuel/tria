import 'package:path/path.dart' as p;

import '../../domain/file_entry.dart';

/// How a file should be shown on screen.
enum PreviewKind { image, generic, cloudPlaceholder }

const _imageExtensions = {
  '.jpg',
  '.jpeg',
  '.png',
  '.heic',
  '.heif',
  '.webp',
  '.gif',
  '.bmp',
  '.tiff',
};

/// Decides how to present [entry].
///
/// Cloud placeholders win over extension: the file claims to be a photo but
/// its bytes are not on this machine, and rendering it would show a broken
/// image instead of an explanation.
PreviewKind previewKindFor(FileEntry entry) {
  if (entry.isCloudPlaceholder) return PreviewKind.cloudPlaceholder;
  final ext = p.extension(entry.path).toLowerCase();
  return _imageExtensions.contains(ext) ? PreviewKind.image : PreviewKind.generic;
}
