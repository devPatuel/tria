import 'package:flutter_test/flutter_test.dart';
import 'package:tria/domain/destination.dart';
import 'package:tria/domain/session_config.dart';

void main() {
  SessionConfig config(List<Destination> destinations) => SessionConfig(
        id: 's1',
        sourceRoot: '/photos',
        recursive: true,
        destinations: destinations,
      );

  test('soft trash lives inside the source root', () {
    expect(config([]).trashPath, '/photos/_trash');
  });

  test('rejects two destinations on the same slot', () {
    final duplicated = [
      Destination(slot: 1, label: 'Family', path: '/a'),
      Destination(slot: 1, label: 'Friends', path: '/b'),
    ];
    expect(() => config(duplicated), throwsArgumentError);
  });

  test('looks a destination up by slot', () {
    final c = config([Destination(slot: 3, label: 'Trips', path: '/trips')]);
    expect(c.destinationForSlot(3)?.label, 'Trips');
    expect(c.destinationForSlot(5), isNull);
  });
}
