/// French date labels, written out by hand to avoid loading intl locale
/// data at startup.
const _months = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];
const _shortMonths = [
  'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
  'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
];
const _weekdays = [
  'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche',
];

String _capitalize(String s) => s[0].toUpperCase() + s.substring(1);

/// "Septembre 2026"
String formatMonthYear(DateTime d) => '${_capitalize(_months[d.month - 1])} ${d.year}';

/// "sept." - the short month, for compact date badges.
String formatShortMonth(DateTime d) => _shortMonths[d.month - 1];

/// "Mardi 22 septembre 2026"
String formatLongDate(DateTime d) =>
    '${_capitalize(_weekdays[d.weekday - 1])} ${d.day} ${_months[d.month - 1]} ${d.year}';

/// "22/09/2026"
String formatNumericDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// How long ago [d] was, by calendar day: "aujourd'hui", "hier",
/// "il y a 5 j", "il y a 3 mois", "il y a 2 ans".
String formatSince(DateTime d, DateTime now) {
  final days = DateTime(now.year, now.month, now.day)
      .difference(DateTime(d.year, d.month, d.day))
      .inDays;
  if (days <= 0) return "aujourd'hui";
  if (days == 1) return 'hier';
  if (days < 31) return 'il y a $days j';
  if (days < 365) return 'il y a ${days ~/ 30} mois';
  final years = days ~/ 365;
  return 'il y a $years an${years > 1 ? 's' : ''}';
}
