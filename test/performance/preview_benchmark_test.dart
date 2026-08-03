import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tria/core/preview/preview_cache.dart';

import '../support/fixtures.dart';

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('tria_bench_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('a cache hit is at least ten times faster than a cold read', () async {
    final cache = PreviewCache(capacity: 4);
    writeFakeImage(tmp, 'a.jpg', bytes: 4 * 1024 * 1024);
    final path = '${tmp.path}/a.jpg';

    final cold = Stopwatch()..start();
    await cache.load(path);
    cold.stop();

    final warm = Stopwatch()..start();
    for (var i = 0; i < 10; i++) {
      await cache.load(path);
    }
    warm.stop();

    final perWarmRead = warm.elapsedMicroseconds / 10;
    // Benchmarks are only useful if the numbers are visible when they pass.
    stdout.writeln('  [bench] 4 MB read: cold ${cold.elapsedMicroseconds}us, '
        'warm ${perWarmRead.toStringAsFixed(1)}us');

    expect(perWarmRead * 10, lessThan(cold.elapsedMicroseconds),
        reason: 'cold ${cold.elapsedMicroseconds}us vs warm ${perWarmRead}us');
  });

  test('preloading three files finishes well under a second', () async {
    final cache = PreviewCache(capacity: 8);
    for (final name in ['a.jpg', 'b.jpg', 'c.jpg']) {
      writeFakeImage(tmp, name, bytes: 4 * 1024 * 1024);
    }

    final watch = Stopwatch()..start();
    cache.preload([
      '${tmp.path}/a.jpg',
      '${tmp.path}/b.jpg',
      '${tmp.path}/c.jpg',
    ]);
    while (cache.size < 3) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    watch.stop();
    stdout.writeln('  [bench] preloading 3 x 4 MB: ${watch.elapsedMilliseconds}ms');

    expect(watch.elapsedMilliseconds, lessThan(1000));
  });
}
