/// Kind of flight. Flights stored before disciplines existed have no
/// discipline field and are speedflying flights.
enum Discipline {
  // Declaration order is the display order (tabs, pickers).
  parapente('Parapente'),
  speedflying('Speedflying');

  final String label;

  const Discipline(this.label);

  static Discipline? tryParse(String? name) {
    for (final d in values) {
      if (d.name == name) return d;
    }
    return null;
  }
}
