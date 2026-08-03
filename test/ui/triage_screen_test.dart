import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tria/core/fs/file_mover.dart';
import 'package:tria/core/fs/operation_queue.dart';
import 'package:tria/core/fs/reverter.dart';
import 'package:tria/core/fs/soft_trash.dart';
import 'package:tria/core/preview/preview_cache.dart';
import 'package:tria/core/journal/journal.dart';
import 'package:tria/core/scanner/file_scanner.dart';
import 'package:tria/domain/destination.dart';
import 'package:tria/domain/session_config.dart';
import 'package:tria/state/session_controller.dart';
import 'package:tria/ui/triage_screen.dart';

import '../support/fixtures.dart';

/// Widget tests run on a fake clock where real file reads never complete, and
/// the cache already has its own tests. This keeps the screen tests about the
/// screen.
class _NoDiskCache extends PreviewCache {
  @override
  Future<Uint8List?> load(String path) async => null;

  @override
  void preload(Iterable<String> paths) {}
}

void main() {
  late Directory tmp;
  late SessionController controller;
  late OperationQueue queue;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('tria_ui_');
    final source = Directory('${tmp.path}/source')..createSync();
    writeFakeImage(source, 'a.jpg');
    writeFakeImage(source, 'b.jpg');

    final config = SessionConfig(
      id: 's1',
      sourceRoot: source.path,
      recursive: true,
      destinations: [
        Destination(slot: 1, label: 'Family', path: '${tmp.path}/family'),
      ],
    );
    final journal = JsonlJournal(File('${tmp.path}/journal.jsonl'));
    final mover = FileMover();
    queue = OperationQueue(
      config: config,
      journal: journal,
      mover: mover,
      trash: SoftTrash(config.trashPath, mover),
    );
    controller = SessionController(
      config: config,
      queue: queue,
      reverter: Reverter(journal, mover),
      scanner: FileScanner(),
    );
    await controller.start();
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  Widget wrap() => MaterialApp(
        home: ChangeNotifierProvider.value(
          value: controller,
          child: TriageScreen(cache: _NoDiskCache()),
        ),
      );

  testWidgets('shows the destination labels and the progress counter',
      (tester) async {
    await tester.pumpWidget(wrap());

    expect(find.text('Family'), findsOneWidget);
    expect(find.text('0/2'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('pressing 1 advances the counter', (tester) async {
    await tester.pumpWidget(wrap());

    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.pump();

    expect(find.text('1/2'), findsOneWidget);
    // The queued move is deliberately not awaited here: widget tests run on a
    // fake clock where it never progresses, and awaiting it through
    // tester.runAsync deadlocks. What the move does on disk is covered by the
    // operation queue's own tests.
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('shows the finished state when nothing is left', (tester) async {
    await tester.pumpWidget(wrap());

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(find.text('Session finished'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
