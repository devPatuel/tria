/// A file waiting to be sorted.
///
/// [isCloudPlaceholder] marks files that iCloud or OneDrive have evicted from
/// local storage: they look like normal files but have no content to preview,
/// so they must be downloaded or skipped rather than shown as broken.
class FileEntry {
  final String path;
  final int sizeBytes;
  final DateTime modifiedAt;
  final bool isCloudPlaceholder;

  const FileEntry({
    required this.path,
    required this.sizeBytes,
    required this.modifiedAt,
    this.isCloudPlaceholder = false,
  });
}
