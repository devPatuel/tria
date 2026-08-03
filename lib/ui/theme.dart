import 'package:flutter/material.dart';

/// Every colour in the application, in one place.
///
/// Photographs are the content: the interface around them is deliberately
/// desaturated so it never competes with what the user is looking at. A single
/// warm accent marks the only things that need to be found instantly — the
/// destination keys — and warm was chosen because photographs usually are, so
/// the accent belongs to the same world instead of fighting it.
class TriaColors {
  const TriaColors._();

  static const background = Color(0xFF0F1012);
  static const surface = Color(0xFF17191D);
  static const surfaceHigh = Color(0xFF1F2229);
  static const border = Color(0xFF2A2E36);
  static const accent = Color(0xFFE8A33D);
  static const onAccent = Color(0xFF1A1206);
  static const text = Color(0xFFE8EAED);
  static const textDim = Color(0xFF9AA0A8);
  static const danger = Color(0xFFE5534B);
}

/// Timing for every transition in the application.
///
/// Short by mandate: at two decisions per second, an animation longer than a
/// few frames stops being feedback and becomes a queue the user waits in.
class TriaMotion {
  const TriaMotion._();

  static const decision = Duration(milliseconds: 120);
  static const curve = Curves.easeOut;
}

/// Corner radius, shared so panels and controls agree.
const double kTriaRadius = 10;

/// The application theme.
///
/// The one rule worth stating: a disabled control keeps a visible background,
/// border and label. Material's default is to fade it almost to nothing, which
/// on a dark background makes the control vanish — and a user who cannot see a
/// button concludes the app is broken, not that they have a step left to do.
ThemeData triaDarkTheme() {
  const scheme = ColorScheme.dark(
    surface: TriaColors.background,
    onSurface: TriaColors.text,
    primary: TriaColors.accent,
    onPrimary: TriaColors.onAccent,
    secondary: TriaColors.accent,
    onSecondary: TriaColors.onAccent,
    error: TriaColors.danger,
    outline: TriaColors.border,
  );

  const tabular = [FontFeature.tabularFigures()];

  final textTheme = const TextTheme(
    headlineSmall: TextStyle(
      color: TriaColors.text,
      fontSize: 22,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: TextStyle(
      color: TriaColors.text,
      fontSize: 15,
      fontWeight: FontWeight.w600,
    ),
    bodyMedium: TextStyle(color: TriaColors.text, fontSize: 14),
    bodySmall: TextStyle(color: TriaColors.textDim, fontSize: 12),
    // Counters live here: tabular figures keep 9 → 10 from shifting the layout.
    labelLarge: TextStyle(
      color: TriaColors.text,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      fontFeatures: tabular,
    ),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: TriaColors.background,
    canvasColor: TriaColors.background,
    dividerColor: TriaColors.border,
    textTheme: textTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: TriaColors.background,
      foregroundColor: TriaColors.text,
      elevation: 0,
      centerTitle: false,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return TriaColors.surfaceHigh;
          }
          return TriaColors.accent;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return TriaColors.textDim;
          return TriaColors.onAccent;
        }),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return const BorderSide(color: TriaColors.border);
          }
          return BorderSide.none;
        }),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(kTriaRadius)),
        ),
        textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: const WidgetStatePropertyAll(TriaColors.text),
        backgroundColor: const WidgetStatePropertyAll(TriaColors.surfaceHigh),
        side: const WidgetStatePropertyAll(BorderSide(color: TriaColors.border)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(kTriaRadius)),
        ),
        textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        foregroundColor: const WidgetStatePropertyAll(TriaColors.textDim),
        textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        foregroundColor: const WidgetStatePropertyAll(TriaColors.text),
        backgroundColor: const WidgetStatePropertyAll(TriaColors.surfaceHigh),
        side: const WidgetStatePropertyAll(BorderSide(color: TriaColors.border)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(kTriaRadius)),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: TriaColors.surface,
      labelStyle: const TextStyle(color: TriaColors.textDim),
      hintStyle: const TextStyle(color: TriaColors.textDim),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kTriaRadius),
        borderSide: const BorderSide(color: TriaColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kTriaRadius),
        borderSide: const BorderSide(color: TriaColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kTriaRadius),
        borderSide: const BorderSide(color: TriaColors.accent, width: 2),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return TriaColors.accent;
        return TriaColors.textDim;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return TriaColors.accent.withValues(alpha: 0.3);
        }
        return TriaColors.surfaceHigh;
      }),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: TriaColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kTriaRadius + 4),
      ),
    ),
  );
}
