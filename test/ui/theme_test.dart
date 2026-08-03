import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tria/ui/theme.dart';

void main() {
  test('a disabled button stays visible instead of fading out', () {
    final theme = triaDarkTheme();
    final style = theme.filledButtonTheme.style!;

    final disabled = style.backgroundColor!.resolve({WidgetState.disabled})!;
    final enabled = style.backgroundColor!.resolve({})!;

    expect(disabled.a, greaterThan(0.3),
        reason: 'an invisible control reads as a broken app');
    expect(disabled, isNot(enabled));
  });

  test('motion is short enough to keep up with fast keystrokes', () {
    expect(TriaMotion.decision.inMilliseconds, lessThanOrEqualTo(150));
  });

  test('counters use tabular figures so they do not shift the layout', () {
    final theme = triaDarkTheme();
    expect(theme.textTheme.labelLarge!.fontFeatures,
        contains(const FontFeature.tabularFigures()));
  });
}
