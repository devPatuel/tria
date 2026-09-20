import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tria/core/fs/file_mover.dart';
import 'package:tria/core/fs/move_result.dart';

import '../../support/fixtures.dart';

void main() {
  late Directory tmp;
  late Directory source;
  late Directory target;
  late FileMover mover;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('tria_mover_');
    source = Directory('${tmp.path}/source')..createSync();
    target = Directory('${tmp.path}/family')..createSync();
    mover = FileMover();
  });

  tearDown(() {
    // A read-only folder cannot be deleted until it is writable again.
    Process.runSync('chmod', ['-R', 'u+w', tmp.path]);
    tmp.deleteSync(recursive: true);
  });

  test('moves a file into the target folder', () async {
    writeFakeImage(source, 'IMG_0042.jpg');

    final result = await mover.move('${source.path}/IMG_0042.jpg', target.path);

    expect(result.ok, isTrue);
    expect(result.actualPath, '${target.path}/IMG_0042.jpg');
    expect(File('${target.path}/IMG_0042.jpg').existsSync(), isTrue);
    expect(File('${source.path}/IMG_0042.jpg').existsSync(), isFalse);
  });

  test('never overwrites: a colliding name gets a numbered suffix', () async {
    writeFakeImage(source, 'IMG_0042.jpg', bytes: 10);
    writeFakeImage(target, 'IMG_0042.jpg', bytes: 999);

    final result = await mover.move('${source.path}/IMG_0042.jpg', target.path);

    expect(result.actualPath, '${target.path}/IMG_0042 (2).jpg');
    expect(File('${target.path}/IMG_0042.jpg').lengthSync(), 999,
        reason: 'the pre-existing file must be untouched');
  });

  test('keeps counting up when several suffixes are taken', () async {
    writeFakeImage(source, 'a.jpg');
    writeFakeImage(target, 'a.jpg');
    writeFakeImage(target, 'a (2).jpg');

    final result = await mover.move('${source.path}/a.jpg', target.path);

    expect(result.actualPath, '${target.path}/a (3).jpg');
  });

  test('creates the target folder when it does not exist yet', () async {
    writeFakeImage(source, 'a.jpg');
    final fresh = '${tmp.path}/brand_new';

    final result = await mover.move('${source.path}/a.jpg', fresh);

    expect(result.ok, isTrue);
    expect(File('$fresh/a.jpg').existsSync(), isTrue);
  });

  test('reports a missing source instead of throwing', () async {
    final result = await mover.move('${source.path}/ghost.jpg', target.path);

    expect(result.ok, isFalse);
    expect(result.error, MoveError.sourceMissing);
  });

  test('preserves the modification time', () async {
    final file = writeFakeImage(source, 'a.jpg');
    final when = DateTime.utc(2019, 3, 12);
    file.setLastModifiedSync(when);

    await mover.move('${source.path}/a.jpg', target.path);

    expect(File('${target.path}/a.jpg').lastModifiedSync().toUtc(), when);
  });

  test('a read-only destination is reported as such, not as unknown', () async {
    writeFakeImage(source, 'IMG_0042.jpg');
    // An existing folder Tría cannot write to: a drive that turned read-only
    // mid-session, which is how this fails in the real world.
    Process.runSync('chmod', ['500', target.path]);

    final result = await mover.move('${source.path}/IMG_0042.jpg', target.path);

    expect(result.ok, isFalse);
    expect(result.error, MoveError.destinationNotWritable);
    expect(File('${source.path}/IMG_0042.jpg').existsSync(), isTrue,
        reason: 'a failed move must never lose the original');
  }, skip: Platform.isWindows ? 'chmod is POSIX only' : null);
}
