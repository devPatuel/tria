import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tria/core/fs/file_mover.dart';
import 'package:tria/core/fs/soft_trash.dart';

import '../../support/fixtures.dart';

void main() {
  late Directory tmp;
  late Directory source;
  late SoftTrash trash;
  late String trashPath;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('tria_trash_');
    source = Directory('${tmp.path}/source')..createSync();
    trashPath = '${source.path}/_trash';
    trash = SoftTrash(trashPath, FileMover());
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  test('sending a file to trash moves it, it does not delete it', () async {
    writeFakeImage(source, 'meme.jpg');

    final result = await trash.send('${source.path}/meme.jpg');

    expect(result.ok, isTrue);
    expect(File('$trashPath/meme.jpg').existsSync(), isTrue);
  });

  test('counts what is waiting in the trash', () async {
    writeFakeImage(source, 'a.jpg');
    writeFakeImage(source, 'b.jpg');
    await trash.send('${source.path}/a.jpg');
    await trash.send('${source.path}/b.jpg');

    expect(await trash.count(), 2);
  });

  test('emptying deletes for real and reports how many', () async {
    writeFakeImage(source, 'a.jpg');
    await trash.send('${source.path}/a.jpg');

    expect(await trash.empty(), 1);
    expect(Directory(trashPath).listSync(), isEmpty);
  });

  test('emptying an absent trash folder is a no-op', () async {
    expect(await trash.empty(), 0);
  });
}
