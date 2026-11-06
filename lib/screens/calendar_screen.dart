import 'package:flutter/material.dart';

import '../models/discipline.dart';
import '../models/flight_entry.dart';
import '../theme/app_colors.dart';
import '../utils/date_format.dart';
import '../utils/flight_numbering.dart';
import '../widgets/choice_sheet.dart';
import '../widgets/discipline_icon.dart';

/// Every flight on a month calendar: days with flights are marked, and
/// tapping one lists its flights. Months change with the arrows, a swipe,
/// or the month title (list of the months with flights).
class CalendarScreen extends StatefulWidget {
  /// The current flights, read again after a flight is opened (it may
  /// have been edited or deleted).
  final List<FlightEntry> Function() flights;
  final Future<void> Function(FlightEntry) onOpenFlight;

  const CalendarScreen({
    super.key,
    required this.flights,
    required this.onOpenFlight,
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const _weekdays = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  late DateTime _firstMonth;
  late int _monthCount;
  late final PageController _pages;
  late int _page;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final dates = widget.flights().map((f) => f.date);
    final first = dates.isEmpty
        ? now
        : dates.reduce((a, b) => a.isBefore(b) ? a : b);
    final last = dates.isEmpty
        ? now
        : dates.reduce((a, b) => a.isAfter(b) ? a : b);
    _firstMonth = DateTime(first.year, first.month);
    final end = last.isAfter(now) ? last : now;
    _monthCount = _monthIndex(DateTime(end.year, end.month)) + 1;
    // Opens on the current month.
    _page = _monthIndex(DateTime(now.year, now.month));
    _pages = PageController(initialPage: _page);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  int _monthIndex(DateTime month) =>
      (month.year - _firstMonth.year) * 12 + month.month - _firstMonth.month;

  DateTime _monthAt(int index) =>
      DateTime(_firstMonth.year, _firstMonth.month + index);

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Flights per day, oldest first within a day.
  Map<DateTime, List<FlightEntry>> get _byDay {
    final map = <DateTime, List<FlightEntry>>{};
    final sorted = List<FlightEntry>.of(widget.flights())
      ..sort(compareChronologically);
    for (final f in sorted) {
      map.putIfAbsent(_day(f.date), () => []).add(f);
    }
    return map;
  }

  static int _count(Iterable<FlightEntry> flights) =>
      flights.fold(0, (sum, f) => sum + f.count);

  void _goTo(int page) => _pages.animateToPage(
    page,
    duration: const Duration(milliseconds: 250),
    curve: Curves.easeOut,
  );

  Future<void> _pickMonth(Map<DateTime, List<FlightEntry>> byDay) async {
    final perMonth = <DateTime, int>{};
    byDay.forEach((day, flights) {
      final month = DateTime(day.year, day.month);
      perMonth[month] = (perMonth[month] ?? 0) + _count(flights);
    });
    final months = perMonth.keys.toList()..sort((a, b) => b.compareTo(a));
    String label(DateTime m) {
      final n = perMonth[m]!;
      return '${formatMonthYear(m)} · $n vol${n > 1 ? 's' : ''}';
    }

    final picked = await showChoiceSheet(
      context,
      title: 'Mois avec des vols',
      options: [for (final m in months) label(m)],
      selected: perMonth.containsKey(_monthAt(_page))
          ? label(_monthAt(_page))
          : null,
    );
    if (picked == null) return;
    final month = months.firstWhere((m) => label(m) == picked);
    _goTo(_monthIndex(month));
  }

  Future<void> _open(FlightEntry flight) async {
    await widget.onOpenFlight(flight);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final byDay = _byDay;
    final month = _monthAt(_page);
    final monthCount = _count(
      byDay.entries
          .where((e) => e.key.year == month.year && e.key.month == month.month)
          .expand((e) => e.value),
    );
    final now = DateTime.now();
    final isCurrentMonth = month.year == now.year && month.month == now.month;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendrier'),
        actions: [
          if (!isCurrentMonth)
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: () =>
                  _goTo(_monthIndex(DateTime(now.year, now.month))),
              child: const Text("Aujourd'hui"),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Mois précédent',
                  onPressed: _page > 0 ? () => _goTo(_page - 1) : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _pickMonth(byDay),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                formatMonthYear(month),
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const Icon(Icons.expand_more),
                            ],
                          ),
                          Text(
                            monthCount == 0
                                ? 'Aucun vol'
                                : '$monthCount vol${monthCount > 1 ? 's' : ''}',
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Mois suivant',
                  onPressed: _page < _monthCount - 1
                      ? () => _goTo(_page + 1)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                for (final d in _weekdays)
                  Expanded(
                    child: Text(
                      d,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            // Six weeks of square-ish cells.
            height: (MediaQuery.of(context).size.width - 24) / 7 * 6,
            child: PageView.builder(
              controller: _pages,
              itemCount: _monthCount,
              onPageChanged: (p) => setState(() {
                _page = p;
                _selectedDay = null;
              }),
              itemBuilder: (context, index) =>
                  _monthGrid(_monthAt(index), byDay),
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _dayFlights(byDay)),
        ],
      ),
    );
  }

  Widget _monthGrid(DateTime month, Map<DateTime, List<FlightEntry>> byDay) {
    final cs = Theme.of(context).colorScheme;
    final accent = AppColors.accentOn(context);
    final today = _day(DateTime.now());
    final leading = month.weekday - 1; // Monday first
    final days = DateUtils.getDaysInMonth(month.year, month.month);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GridView.count(
        crossAxisCount: 7,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (var i = 0; i < leading; i++) const SizedBox.shrink(),
          for (var d = 1; d <= days; d++)
            Builder(
              builder: (context) {
                final day = DateTime(month.year, month.month, d);
                final flights = byDay[day];
                final n = flights == null ? 0 : _count(flights);
                final selected = day == _selectedDay;
                final isToday = day == today;
                return Padding(
                  padding: const EdgeInsets.all(3),
                  child: Material(
                    color: selected
                        ? AppColors.accent
                        : n > 0
                        ? accent.withValues(alpha: 0.16)
                        : Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: isToday && !selected
                          ? BorderSide(color: accent, width: 1.5)
                          : BorderSide.none,
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: n == 0
                          ? null
                          : () => setState(() => _selectedDay = day),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$d',
                            style: TextStyle(
                              fontWeight: n > 0
                                  ? FontWeight.w800
                                  : FontWeight.w400,
                              color: selected
                                  ? Colors.white
                                  : n > 0
                                  ? accent
                                  : cs.onSurface,
                            ),
                          ),
                          if (n > 0)
                            Text(
                              n > 1 ? '$n vols' : '1 vol',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: selected ? Colors.white : accent,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _dayFlights(Map<DateTime, List<FlightEntry>> byDay) {
    final cs = Theme.of(context).colorScheme;
    final day = _selectedDay;
    final flights = day == null ? null : byDay[day];
    if (day == null || flights == null) {
      return Center(
        child: Text(
          'Touche un jour coloré pour voir ses vols',
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
      );
    }
    final labels = computeFlightNumberLabels(widget.flights());
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            formatLongDate(day),
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        for (final f in flights)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: DisciplineIcon(
                f.discipline,
                color: AppColors.accentOn(context),
              ),
              title: Text(
                f.run.isEmpty ? f.site : '${f.site} · ${f.run}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                [
                  f.discipline.label,
                  if (f.wing.isNotEmpty) f.wing,
                  if (f.discipline == Discipline.parapente &&
                      f.verticalOrDuration.isNotEmpty)
                    f.verticalOrDuration,
                ].join(' · '),
              ),
              trailing: Text(
                labels[f.id] ?? '',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              onTap: () => _open(f),
            ),
          ),
      ],
    );
  }
}
