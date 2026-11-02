import '../models/discipline.dart';
import '../models/flight_entry.dart';

String formatFlightNumberRange(int start, int count) {
  return count > 1 ? '#$start - #${start + count - 1}' : '#$start';
}

/// Assigns each flight a display number reflecting its position in
/// chronological (ascending date) order, so numbers always stay sorted by
/// date regardless of the order flights were entered or edited in. Each
/// discipline has its own counter.
Map<String, String> computeFlightNumberLabels(List<FlightEntry> flights) {
  final labels = <String, String>{};
  for (final discipline in Discipline.values) {
    labels.addAll(_numberChronologically(
        flights.where((f) => f.discipline == discipline)));
  }
  return labels;
}

Map<String, String> _numberChronologically(Iterable<FlightEntry> flights) {
  final sorted = List<FlightEntry>.of(flights)
    ..sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      if (byDate != 0) return byDate;
      final aNum = int.tryParse(a.sourceNumber ?? '');
      final bNum = int.tryParse(b.sourceNumber ?? '');
      if (aNum != null && bNum != null && aNum != bNum) return aNum.compareTo(bNum);
      return a.id.compareTo(b.id);
    });

  final labels = <String, String>{};
  var next = 1;
  for (final f in sorted) {
    labels[f.id] = formatFlightNumberRange(next, f.count);
    next += f.count;
  }
  return labels;
}
