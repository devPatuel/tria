import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/preview/preview_types.dart';
import '../../domain/file_entry.dart';

/// Shows the current file: the image itself, or an honest explanation of why
/// it cannot be shown.
class PreviewPane extends StatelessWidget {
  final FileEntry entry;
  final Uint8List? bytes;

  const PreviewPane({super.key, required this.entry, this.bytes});

  @override
  Widget build(BuildContext context) {
    switch (previewKindFor(entry)) {
      case PreviewKind.image:
        if (bytes == null) return const Center(child: CircularProgressIndicator());
        return Image.memory(bytes!, fit: BoxFit.contain, gaplessPlayback: true);
      case PreviewKind.cloudPlaceholder:
        return const _Notice(
          icon: Icons.cloud_off,
          message: 'Stored in the cloud — not downloaded to this Mac',
        );
      case PreviewKind.generic:
        return _Notice(
          icon: Icons.insert_drive_file_outlined,
          message: entry.path.split(Platform.pathSeparator).last,
        );
    }
  }
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final String message;

  const _Notice({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
