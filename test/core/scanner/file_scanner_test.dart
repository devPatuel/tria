import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tria/core/scanner/file_scanner.dart';

import '../../support/fixtures.dart';

void main() {
  late Directory tmp;
  late FileScanner scanner;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('tria_scan_');
    scanner = FileScanner();
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  test('lists files in the root folder', () async {
    writeFakeImage(tmp, 'a.jpg');
    writeFakeImage(tmp, 'b.jpg');

    final found = await scanner.scan(tmp.path, recursive: false).toList();

    expect(found.map((e) => e.path.split(Platform.pathSeparator).last).toSet(),
        {'a.jpg', 'b.jpg'});
  });

  test('flattens subfolders when recursive', () async {
    writeFakeImage(tmp, 'a.jpg');
    writeFakeImage(Directory('${tmp.path}/2019')..createSync(), 'b.jpg');

    final found = await scanner.scan(tmp.path, recursive: true).toList();

    expect(found.length, 2);
  });

  test('ignores subfolders when not recursive', () async {
    writeFakeImage(tmp, 'a.jpg');
    writeFakeImage(Directory('${tmp.path}/2019')..createSync(), 'b.jpg');

    final found = await scanner.scan(tmp.path, recursive: false).toList();

    expect(found.length, 1);
  });

  test('never returns files from the excluded folder', () async {
    writeFakeImage(tmp, 'a.jpg');
    writeFakeImage(Directory('${tmp.path}/_trash')..createSync(), 'trashed.jpg');

    final found = await scanner
        .scan(tmp.path, recursive: true, excludeFolder: '_trash')
        .toList();

    expect(found.length, 1);
    expect(found.single.path, endsWith('a.jpg'));
  });

  test('reports size and modification time', () async {
    final file = writeFakeImage(tmp, 'a.jpg', bytes: 2048);
    file.setLastModifiedSync(DateTime.utc(2019, 3, 12));

    final entry = (await scanner.scan(tmp.path, recursive: false).toList()).single;

    expect(entry.sizeBytes, 2048);
    expect(entry.modifiedAt.toUtc(), DateTime.utc(2019, 3, 12));
  });

  test('flags iCloud placeholders instead of treating them as normal files', () async {
    File('${tmp.path}/.IMG_0042.jpg.icloud').writeAsStringSync('');

    final entry = (await scanner.scan(tmp.path, recursive: false).toList()).single;

    expect(entry.isCloudPlaceholder, isTrue);
  });

  test('ignores the AppleDouble sidecars macOS writes on exFAT', () async {
    writeFakeImage(tmp, 'a.jpg');
    File('${tmp.path}/._a.jpg').writeAsBytesSync(List.filled(82, 0));

    final found = await scanner.scan(tmp.path, recursive: false).toList();

    expect(found.single.path, endsWith('a.jpg'));
    expect(found.single.path, isNot(contains('._')));
  });
}
