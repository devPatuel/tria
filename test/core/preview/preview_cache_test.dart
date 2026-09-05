import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tria/core/preview/preview_cache.dart';
import 'package:tria/core/preview/preview_types.dart';
import 'package:tria/domain/file_entry.dart';

import '../../support/fixtures.dart';

void main() {
  late Directory tmp;
  late PreviewCache cache;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('tria_preview_');
    cache = PreviewCache(capacity: 3);
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  FileEntry entryFor(String name, {bool cloud = false}) => FileEntry(
        path: '${tmp.path}/$name',
        sizeBytes: 1024,
        modifiedAt: DateTime.utc(2026),
        isCloudPlaceholder: cloud,
      );

  test('classifies known image extensions as images', () {
    for (final name in ['a.jpg', 'a.JPEG', 'a.png', 'a.heic', 'a.webp', 'a.gif']) {
      expect(previewKindFor(entryFor(name)), PreviewKind.image, reason: name);
    }
  });

  test('classifies PDFs so their first page can be rendered', () {
    for (final name in ['a.pdf', 'a.PDF']) {
      expect(previewKindFor(entryFor(name)), PreviewKind.pdf, reason: name);
    }
  });

  test('classifies readable text files', () {
    for (final name in ['a.txt', 'a.md', 'a.csv', 'a.json', 'a.dart', 'a.LOG']) {
      expect(previewKindFor(entryFor(name)), PreviewKind.text, reason: name);
    }
  });

  test('classifies anything else as generic', () {
    for (final name in ['a.docx', 'a.zip', 'a.sketch', 'a']) {
      expect(previewKindFor(entryFor(name)), PreviewKind.generic, reason: name);
    }
  });

  test('a cloud placeholder is never treated as a previewable image', () {
    expect(previewKindFor(entryFor('a.jpg', cloud: true)),
        PreviewKind.cloudPlaceholder);
  });

  test('loads file bytes', () async {
    writeFakeImage(tmp, 'a.jpg', bytes: 512);

    expect((await cache.load('${tmp.path}/a.jpg'))!.length, 512);
  });

  test('returns null for a file that vanished mid-session', () async {
    expect(await cache.load('${tmp.path}/ghost.jpg'), isNull);
  });

  test('preloading fills the cache ahead of the user', () async {
    writeFakeImage(tmp, 'a.jpg');
    writeFakeImage(tmp, 'b.jpg');

    cache.preload(['${tmp.path}/a.jpg', '${tmp.path}/b.jpg']);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(cache.size, 2);
  });

  test('reads only the head of a file when that is all that is needed',
      () async {
    writeFakeImage(tmp, 'huge.log', bytes: 200 * 1024);

    final head = await cache.loadHead('${tmp.path}/huge.log', maxBytes: 4096);

    expect(head!.length, 4096,
        reason: 'a 200 MB log must never be pulled into memory whole');
  });

  test('loading the head of a small file returns all of it', () async {
    writeFakeImage(tmp, 'small.txt', bytes: 100);

    final head = await cache.loadHead('${tmp.path}/small.txt', maxBytes: 4096);

    expect(head!.length, 100);
  });

  test('the head of a missing file is null, not a crash', () async {
    expect(await cache.loadHead('${tmp.path}/ghost.txt'), isNull);
  });

  test('evicts the oldest entry when over capacity', () async {
    for (final name in ['a.jpg', 'b.jpg', 'c.jpg', 'd.jpg']) {
      writeFakeImage(tmp, name);
      await cache.load('${tmp.path}/$name');
    }

    expect(cache.size, 3, reason: 'capacity is 3');
  });
}
