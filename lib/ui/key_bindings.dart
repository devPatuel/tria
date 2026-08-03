import 'package:flutter/services.dart';

import '../domain/decision.dart';

// Not `const`: LogicalKeyboardKey overrides `==`, and Dart rejects keys
// without primitive equality in a constant map.
final _slotKeys = <LogicalKeyboardKey, int>{
  LogicalKeyboardKey.digit1: 1,
  LogicalKeyboardKey.digit2: 2,
  LogicalKeyboardKey.digit3: 3,
  LogicalKeyboardKey.digit4: 4,
  LogicalKeyboardKey.digit5: 5,
  LogicalKeyboardKey.digit6: 6,
  LogicalKeyboardKey.digit7: 7,
  LogicalKeyboardKey.digit8: 8,
  LogicalKeyboardKey.digit9: 9,
};

/// Translates a key press into a decision about [sourcePath].
///
/// Returns null for keys that are not decisions — undo, open and zoom are
/// handled by the screen, because they change what the user sees rather than
/// what happens to the file.
Decision? decisionForKey(LogicalKeyboardKey key, String sourcePath) {
  final slot = _slotKeys[key];
  if (slot != null) {
    return Decision(kind: DecisionKind.move, sourcePath: sourcePath, slot: slot);
  }
  if (key == LogicalKeyboardKey.arrowUp) {
    return Decision(kind: DecisionKind.trash, sourcePath: sourcePath);
  }
  if (key == LogicalKeyboardKey.arrowDown) {
    return Decision(kind: DecisionKind.postpone, sourcePath: sourcePath);
  }
  if (key == LogicalKeyboardKey.arrowRight) {
    return Decision(kind: DecisionKind.keep, sourcePath: sourcePath);
  }
  return null;
}
