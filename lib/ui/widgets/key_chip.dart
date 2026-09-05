import 'package:flutter/material.dart';

import '../theme.dart';

/// The visual form of a keyboard key.
///
/// The whole interaction model is "look at the chip, press that key", so the
/// chip carries the only accent colour in the interface: it must be findable in
/// peripheral vision, without reading.
class KeyChip extends StatelessWidget {
  final String label;

  /// Muted chips are for keys that are always the same (arrows), as opposed to
  /// the numbered destinations the user configured.
  final bool muted;

  const KeyChip({super.key, required this.label, this.muted = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      // Single characters get a square; longer labels like "esc" grow instead
      // of being clipped.
      width: label.length > 1 ? null : 26,
      height: 26,
      padding: label.length > 1
          ? const EdgeInsets.symmetric(horizontal: 8)
          : EdgeInsets.zero,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: muted ? TriaColors.surfaceHigh : TriaColors.accent,
        border: Border.all(color: muted ? TriaColors.border : TriaColors.accent),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: muted ? TriaColors.textDim : TriaColors.onAccent,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}
