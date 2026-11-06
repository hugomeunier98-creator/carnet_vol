import '../models/flight_entry.dart';

/// Minutes counted for a flight with no duration, "plouf", or a text that
/// holds no duration (e.g. "soaring", a vertical drop).
const defaultFlightMinutes = 10;

/// Minutes of one flight read from its duration text: "1h30", "1h",
/// "1.5h", "45min", "10m", "Soaring 1h30"… Else [defaultFlightMinutes].
int flightMinutes(String text) {
  final t = text.toLowerCase();
  final hours = RegExp(r'(\d+(?:[.,]\d+)?)\s*h\s*(\d{1,2})?').firstMatch(t);
  if (hours != null) {
    final h = double.parse(hours.group(1)!.replaceAll(',', '.'));
    final m = int.tryParse(hours.group(2) ?? '') ?? 0;
    return (h * 60).round() + m;
  }
  final minutes = RegExp(r'(\d+)\s*m(?:in)?\b').firstMatch(t);
  if (minutes != null) return int.parse(minutes.group(1)!);
  return defaultFlightMinutes;
}

/// Minutes of an entry: its duration times the identical flights it groups.
int entryMinutes(FlightEntry f) => flightMinutes(f.verticalOrDuration) * f.count;

/// "12 h 30", "45 min".
String formatMinutes(int minutes) {
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h h' : '$h h ${m.toString().padLeft(2, '0')}';
}

/// Totals of [flights] per key, largest first; empty keys are skipped.
List<(String, int)> totalsBy(
  Iterable<FlightEntry> flights,
  String Function(FlightEntry) key,
  int Function(FlightEntry) value,
) {
  final totals = <String, int>{};
  for (final f in flights) {
    final k = key(f).trim();
    if (k.isEmpty) continue;
    totals[k] = (totals[k] ?? 0) + value(f);
  }
  return totals.entries.map((e) => (e.key, e.value)).toList()
    ..sort((a, b) => b.$2.compareTo(a.$2));
}
