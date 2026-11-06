import 'package:flutter/material.dart';

/// The app's single accent: top bars, buttons, highlighted text. iOS paints
/// the status bar once, at launch, so every screen shares the top bar
/// colour; the rest of the app follows it.
class AppColors {
  static const defaultAccent = Color(0xFFD9480F);

  /// Accents the user can choose (menu ⋯ → Couleur de l'appli).
  static const choices = <(String, Color)>[
    ('Orange', defaultAccent),
    ('Rouge', Color(0xFFC92A2A)),
    ('Framboise', Color(0xFFC2255C)),
    ('Violet', Color(0xFF7048E8)),
    ('Indigo', Color(0xFF3B5BDB)),
    ('Bleu', Color(0xFF1971C2)),
    ('Pétrole', Color(0xFF0C8599)),
    ('Vert', Color(0xFF2B8A3E)),
    ('Ardoise', Color(0xFF495057)),
  ];

  /// The chosen accent, set from the settings before the app is built
  /// (see AppSettings); the app is rebuilt when it changes.
  static Color accent = defaultAccent;

  /// [accent] as text/icon colour on the current surface: lifted in dark
  /// mode, where the saturated base colour lacks contrast.
  static Color accentOn(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? Color.lerp(accent, Colors.white, 0.35)!
      : accent;
}
