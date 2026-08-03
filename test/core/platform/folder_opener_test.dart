import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tria/core/platform/folder_opener.dart';

void main() {
  late Directory tmp;
  late List<List<String>> calls;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('tria_opener_');
    calls = [];
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  FolderOpener openerFor(String platform) => FolderOpener(
        platformOverride: platform,
        runner: (executable, arguments) async {
          calls.add([executable, ...arguments]);
          return 0;
        },
      );

  test('uses open on macOS', () async {
    expect(await openerFor('macos').reveal(tmp.path), isTrue);
    expect(calls.single, ['open', tmp.path]);
  });

  test('uses explorer on Windows', () async {
    expect(await openerFor('windows').reveal(tmp.path), isTrue);
    expect(calls.single, ['explorer', tmp.path]);
  });

  test('a folder that no longer exists is reported, not thrown', () async {
    expect(await openerFor('macos').reveal('${tmp.path}/gone'), isFalse);
    expect(calls, isEmpty);
  });

  test('a non-zero exit code counts as failure', () async {
    final opener = FolderOpener(
      platformOverride: 'macos',
      runner: (executable, arguments) async => 1,
    );

    expect(await opener.reveal(tmp.path), isFalse);
  });

  test('a process that cannot be launched is reported, not thrown', () async {
    final opener = FolderOpener(
      platformOverride: 'macos',
      runner: (executable, arguments) async => throw const ProcessException('open', []),
    );

    expect(await opener.reveal(tmp.path), isFalse);
  });
}
