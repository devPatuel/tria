import 'package:flutter_test/flutter_test.dart';
import 'package:tria/domain/destination.dart';

void main() {
  test('accepts slots 1 to 9', () {
    expect(Destination(slot: 1, label: 'Family', path: '/x').slot, 1);
    expect(Destination(slot: 9, label: 'Trips', path: '/y').slot, 9);
  });

  test('rejects slots outside 1..9', () {
    expect(() => Destination(slot: 0, label: 'X', path: '/x'), throwsArgumentError);
    expect(() => Destination(slot: 10, label: 'X', path: '/x'), throwsArgumentError);
  });

  test('rejects an empty label', () {
    expect(() => Destination(slot: 1, label: '', path: '/x'), throwsArgumentError);
  });
}
