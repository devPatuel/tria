import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tria/domain/decision.dart';
import 'package:tria/ui/key_bindings.dart';

void main() {
  const path = '/photos/a.jpg';

  test('number keys 1 to 9 map to move decisions on their slot', () {
    final keys = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit9,
    ];
    final slots = [1, 5, 9];

    for (var i = 0; i < keys.length; i++) {
      final decision = decisionForKey(keys[i], path)!;
      expect(decision.kind, DecisionKind.move);
      expect(decision.slot, slots[i]);
    }
  });

  test('arrow up sends to trash', () {
    expect(decisionForKey(LogicalKeyboardKey.arrowUp, path)!.kind,
        DecisionKind.trash);
  });

  test('arrow down postpones', () {
    expect(decisionForKey(LogicalKeyboardKey.arrowDown, path)!.kind,
        DecisionKind.postpone);
  });

  test('arrow right keeps the file in place', () {
    expect(decisionForKey(LogicalKeyboardKey.arrowRight, path)!.kind,
        DecisionKind.keep);
  });

  test('arrow left is undo, which is not a decision', () {
    expect(decisionForKey(LogicalKeyboardKey.arrowLeft, path), isNull);
  });

  test('unbound keys produce nothing', () {
    expect(decisionForKey(LogicalKeyboardKey.keyQ, path), isNull);
  });
}
