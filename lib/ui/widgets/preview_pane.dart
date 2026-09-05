import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../core/preview/preview_types.dart';
import '../../domain/file_entry.dart';
import '../theme.dart';

/// Shows the current file: the image itself, the first page of a PDF, the
/// beginning of a text file, or an honest explanation of why none of that is
/// possible.
class PreviewPane extends StatelessWidget {
  final FileEntry entry;
  final Uint8List? bytes;

  const PreviewPane({super.key, required this.entry, this.bytes});

  @override
  Widget build(BuildContext context) {
    switch (previewKindFor(entry)) {
      case PreviewKind.image:
        if (bytes == null) return const Center(child: CircularProgressIndicator());
        return Image.memory(
          bytes!,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          // Renamed files, truncated downloads and corrupt copies are the
          // normal contents of a folder worth sorting. One of them must not
          // take the screen down with it.
          errorBuilder: (context, error, stackTrace) => const _Notice(
            icon: Icons.broken_image_outlined,
            message: 'This image could not be shown — the file may be damaged',
          ),
        );
      case PreviewKind.pdf:
        return PdfPreview(path: entry.path);
      case PreviewKind.text:
        if (bytes == null) return const Center(child: CircularProgressIndicator());
        return TextPreview(bytes: bytes!);
      case PreviewKind.cloudPlaceholder:
        return const _Notice(
          icon: Icons.cloud_off,
          message: 'Stored in the cloud — not downloaded to this machine',
        );
      case PreviewKind.generic:
        return _Notice(
          icon: Icons.insert_drive_file_outlined,
          message: entry.path.split(Platform.pathSeparator).last,
        );
    }
  }
}

/// The first page of a PDF.
///
/// Only the first page: this is a sorting decision, not a reading session, and
/// rendering more would spend time the user never asked for.
class PdfPreview extends StatelessWidget {
  final String path;

  const PdfPreview({super.key, required this.path});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: TriaColors.surface,
      padding: const EdgeInsets.all(12),
      child: PdfDocumentViewBuilder.file(
        path,
        builder: (context, document) {
          if (document == null) {
            return const _Notice(
              icon: Icons.picture_as_pdf_outlined,
              message: 'This PDF could not be opened',
            );
          }
          return PdfPageView(
            document: document,
            pageNumber: 1,
            alignment: Alignment.center,
          );
        },
      ),
    );
  }
}

/// The beginning of a text file.
const _maxPreviewLines = 60;

/// The first lines of a text file, in a monospaced face.
///
/// Truncated on purpose: a 200 MB log would otherwise be laid out in full to
/// answer a question the user settles from the first screenful.
class TextPreview extends StatelessWidget {
  final Uint8List bytes;

  const TextPreview({super.key, required this.bytes});

  @override
  Widget build(BuildContext context) {
    // allowMalformed: a file with one bad byte still deserves a preview.
    final decoded = utf8.decode(
      bytes.length > 64 * 1024 ? bytes.sublist(0, 64 * 1024) : bytes,
      allowMalformed: true,
    );
    final lines = const LineSplitter().convert(decoded);
    final shown = lines.take(_maxPreviewLines).join('\n');
    final truncated = lines.length > _maxPreviewLines;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TriaColors.surface,
        border: Border.all(color: TriaColors.border),
        borderRadius: BorderRadius.circular(kTriaRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                shown,
                style: const TextStyle(
                  fontFamily: 'Menlo',
                  fontFamilyFallback: ['Consolas', 'monospace'],
                  fontSize: 12,
                  height: 1.45,
                  color: TriaColors.text,
                ),
              ),
            ),
          ),
          if (truncated)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                '… ${lines.length - _maxPreviewLines} more lines',
                style: const TextStyle(color: TriaColors.textDim, fontSize: 11),
              ),
            ),
        ],
      ),
    );
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
          Icon(icon, size: 64, color: TriaColors.textDim),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: TriaColors.textDim),
          ),
        ],
      ),
    );
  }
}
