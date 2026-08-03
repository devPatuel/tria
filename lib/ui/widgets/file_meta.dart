import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../domain/file_entry.dart';
import '../theme.dart';

/// Name, size and date of the file on screen.
///
/// The date earns its place: it is the one piece of information that survives
/// no matter how the file was renamed, and often the only thing that tells the
/// user which folder a photo belongs in.
class FileMeta extends StatelessWidget {
  final FileEntry entry;

  const FileMeta({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          p.basename(entry.path),
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          '${formatBytes(entry.sizeBytes)} · ${formatDate(entry.modifiedAt)}',
          style: const TextStyle(color: TriaColors.textDim, fontSize: 12),
        ),
      ],
    );
  }
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Formats a byte count the way a file manager would.
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

/// Formats a date as `12 Mar 2019`.
String formatDate(DateTime when) =>
    '${when.day} ${_months[when.month - 1]} ${when.year}';
