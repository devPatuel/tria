import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tria/core/fs/folder_access.dart';

void main() {
  late Directory tmp;
  late FolderAccess access;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('tria_access_');
    access = FolderAccess();
  });

  tearDown(() {
    // Restore permissions first: a read-only folder cannot be deleted.
    Process.runSync('chmod', ['-R', 'u+w', tmp.path]);
    tmp.deleteSync(recursive: true);
  });

  test('an ordinary folder is writable', () async {
    expect(await access.isWritable(tmp.path), isTrue);
  });

  test('a folder that does not exist yet is writable if it can be created',
      () async {
    expect(await access.isWritable('${tmp.path}/not/there/yet'), isTrue);
  });

  test('a read-only folder is not writable', () async {
    final locked = Directory('${tmp.path}/locked')..createSync();
    Process.runSync('chmod', ['500', locked.path]);

    expect(await access.isWritable(locked.path), isFalse);
  }, skip: Platform.isWindows ? 'chmod is POSIX only' : null);

  test('a path occupied by a file is not writable', () async {
    File('${tmp.path}/a-file').writeAsStringSync('x');

    expect(await access.isWritable('${tmp.path}/a-file'), isFalse);
  });

  test('checking leaves nothing behind', () async {
    await access.isWritable(tmp.path);

    expect(tmp.listSync(), isEmpty);
  });
}
