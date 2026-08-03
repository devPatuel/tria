import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tria/core/storage/profile_store.dart';
import 'package:tria/domain/destination.dart';
import 'package:tria/domain/session_config.dart';

void main() {
  late Directory tmp;
  late ProfileStore store;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('tria_profiles_');
    store = ProfileStore(File('${tmp.path}/profiles.json'));
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  SessionConfig sample() => SessionConfig(
        id: 's1',
        sourceRoot: '/photos/2019',
        recursive: true,
        destinations: [
          Destination(slot: 1, label: 'Family', path: '/sorted/family'),
          Destination(slot: 2, label: 'Friends', path: '/sorted/friends'),
        ],
      );

  test('saves a profile and reads it back intact', () async {
    await store.save('Photos 2019', sample());

    final loaded = (await store.loadAll())['Photos 2019']!;
    expect(loaded.sourceRoot, '/photos/2019');
    expect(loaded.recursive, isTrue);
    expect(loaded.destinations.map((d) => d.label), ['Family', 'Friends']);
    expect(loaded.destinationForSlot(2)?.path, '/sorted/friends');
  });

  test('loading with no file yet returns an empty map', () async {
    expect(await store.loadAll(), isEmpty);
  });

  test('saving the same name twice overwrites instead of duplicating', () async {
    await store.save('P', sample());
    await store.save('P', sample());

    expect((await store.loadAll()).length, 1);
  });

  test('deletes a profile', () async {
    await store.save('P', sample());
    await store.delete('P');

    expect(await store.loadAll(), isEmpty);
  });
}
