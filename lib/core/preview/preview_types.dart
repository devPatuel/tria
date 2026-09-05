import 'package:path/path.dart' as p;

import '../../domain/file_entry.dart';

/// How a file should be shown on screen.
enum PreviewKind {
  /// Decoded and displayed directly.
  image,

  /// First page rendered.
  pdf,

  /// First lines shown as text.
  text,

  /// Nothing to render: name and icon only.
  generic,

  /// The bytes are not on this machine.
  cloudPlaceholder,
}

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

/// Extensions worth showing as text.
///
/// Deliberately a list rather than "anything that decodes as UTF-8": a
/// mislabelled binary would render as pages of noise, which is worse than an
/// honest icon.
const _textExtensions = {
  '.txt',
  '.md',
  '.csv',
  '.json',
  '.yaml',
  '.yml',
  '.log',
  '.xml',
  '.html',
  '.css',
  '.js',
  '.ts',
  '.dart',
  '.py',
  '.java',
  '.sh',
  '.sql',
  '.ini',
  '.conf',
  '.rtf',
};

/// Decides how to present [entry].
///
/// Cloud placeholders win over extension: the file claims to be a photo but
/// its bytes are not on this machine, and rendering it would show a broken
/// image instead of an explanation.
PreviewKind previewKindFor(FileEntry entry) {
  if (entry.isCloudPlaceholder) return PreviewKind.cloudPlaceholder;

  final ext = p.extension(entry.path).toLowerCase();
  if (_imageExtensions.contains(ext)) return PreviewKind.image;
  if (ext == '.pdf') return PreviewKind.pdf;
  if (_textExtensions.contains(ext)) return PreviewKind.text;
  return PreviewKind.generic;
}
