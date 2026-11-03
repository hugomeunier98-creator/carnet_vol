import 'package:flutter/material.dart';

/// The app's single accent: top bars, buttons, highlighted text. iOS paints
/// the status bar once, at launch, so every screen shares the top bar
/// colour; the rest of the app follows it.
class AppColors {
  static const accent = Color(0xFFD9480F);

  /// [accent] as text/icon colour on the current surface: lifted in dark
  /// mode, where the saturated base colour lacks contrast.
  static Color accentOn(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? Color.lerp(accent, Colors.white, 0.35)!
      : accent;
}
