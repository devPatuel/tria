import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tria/domain/file_entry.dart';
import 'package:tria/ui/widgets/preview_pane.dart';

void main() {
  FileEntry entry(String name, {bool cloud = false}) => FileEntry(
        path: '/files/$name',
        sizeBytes: 2048,
        modifiedAt: DateTime.utc(2019, 3, 12),
        isCloudPlaceholder: cloud,
      );

  Future<void> pump(WidgetTester tester, FileEntry e, {Uint8List? bytes}) =>
      tester.pumpWidget(MaterialApp(
        home: Scaffold(body: PreviewPane(entry: e, bytes: bytes)),
      ));

  testWidgets('shows the beginning of a text file', (tester) async {
    final bytes = Uint8List.fromList(utf8.encode('hello\nsecond line\n'));

    await pump(tester, entry('notes.txt'), bytes: bytes);

    expect(find.textContaining('hello'), findsOneWidget);
    expect(find.textContaining('second line'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('truncates a long text file instead of rendering all of it',
      (tester) async {
    final long = List.generate(500, (i) => 'line $i').join('\n');
    final bytes = Uint8List.fromList(utf8.encode(long));

    await pump(tester, entry('big.log'), bytes: bytes);

    expect(find.textContaining('line 0'), findsOneWidget);
    expect(find.textContaining('line 499'), findsNothing);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('renders a PDF through its own widget', (tester) async {
    await pump(tester, entry('invoice.pdf'));

    expect(find.byType(PdfPreview), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('an unknown format still names the file', (tester) async {
    await pump(tester, entry('archive.zip'));

    expect(find.text('archive.zip'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('a file that is not really an image says so', (tester) async {
    // A .jpg whose bytes are not a JPEG: renamed files, truncated downloads and
    // corrupt copies are exactly the mess this app exists to sort out.
    final notAnImage = Uint8List.fromList(utf8.encode('this is not a jpeg'));

    await pump(tester, entry('broken.jpg'), bytes: notAnImage);
    await tester.pump();

    expect(find.textContaining('could not be shown'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('a cloud placeholder explains itself', (tester) async {
    await pump(tester, entry('photo.jpg', cloud: true));

    expect(find.textContaining('cloud'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
