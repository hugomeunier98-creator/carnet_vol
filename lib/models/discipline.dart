import 'package:flutter/material.dart';

/// Kind of flight. Flights stored before disciplines existed have no
/// discipline field and are speedflying flights.
enum Discipline {
  speedflying('Speedflying', Color(0xFFD9480F)),
  parapente('Parapente', Color(0xFF0B7285));

  final String label;
  final Color color;

  const Discipline(this.label, this.color);

  static Discipline? tryParse(String? name) {
    for (final d in values) {
      if (d.name == name) return d;
    }
    return null;
  }
}
