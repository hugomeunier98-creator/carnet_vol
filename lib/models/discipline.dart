import 'package:flutter/material.dart';

/// Kind of flight. Flights stored before disciplines existed have no
/// discipline field and are speedflying flights.
enum Discipline {
  speedflying('Speedflying', Icons.downhill_skiing, Color(0xFFD9480F)),
  parapente('Parapente', Icons.paragliding, Color(0xFF0B7285));

  final String label;
  final IconData icon;
  final Color color;

  const Discipline(this.label, this.icon, this.color);

  static Discipline? tryParse(String? name) {
    for (final d in values) {
      if (d.name == name) return d;
    }
    return null;
  }
}
