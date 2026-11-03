import 'package:flutter/material.dart';

/// Kind of flight. Flights stored before disciplines existed have no
/// discipline field and are speedflying flights.
enum Discipline {
  // Declaration order is the display order (tabs, pickers).
  parapente('Parapente', Color(0xFF0B7285)),
  speedflying('Speedflying', Color(0xFFD9480F));

  final String label;
  final Color color;

  const Discipline(this.label, this.color);

  /// Accent of the "Tout" tab (every discipline), readable under white text
  /// in light and dark mode alike.
  static const allColor = Color(0xFF2F5D8A);

  /// [color] as text/icon colour on the current surface: lifted in dark
  /// mode, where the saturated base colour lacks contrast.
  Color on(BuildContext context) => Theme.of(context).brightness == Brightness.dark
      ? Color.lerp(color, Colors.white, 0.35)!
      : color;

  static Discipline? tryParse(String? name) {
    for (final d in values) {
      if (d.name == name) return d;
    }
    return null;
  }
}
