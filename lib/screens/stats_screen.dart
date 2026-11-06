import 'package:flutter/material.dart';

import '../models/discipline.dart';
import '../models/flight_entry.dart';
import '../theme/app_colors.dart';
import '../utils/date_format.dart';
import '../utils/flight_stats.dart';

/// Figures and charts of the logbook: totals, hours per wing, flights per
/// month, most flown sites. One discipline at a time, or all of them.
class StatsScreen extends StatefulWidget {
  final List<FlightEntry> flights;

  /// The discipline shown first (the home tab's); null for all.
  final Discipline? discipline;

  const StatsScreen({super.key, required this.flights, this.discipline});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late Discipline? _discipline = widget.discipline;
  bool _allWings = false;

  static int _count(Iterable<FlightEntry> flights) =>
      flights.fold(0, (sum, f) => sum + f.count);

  @override
  Widget build(BuildContext context) {
    final flights = widget.flights
        .where((f) => _discipline == null || f.discipline == _discipline)
        .toList();
    // Only parapente logs durations; speedflying counts flights.
    final timed = flights
        .where((f) => f.discipline == Discipline.parapente)
        .toList();
    final isParapente = _discipline == Discipline.parapente;
    final showHours = timed.isNotEmpty;
    final minutes = timed.fold(0, (sum, f) => sum + entryMinutes(f));
    final count = _count(flights);
    final wings = isParapente
        ? totalsBy(flights, (f) => f.wing, entryMinutes)
        : totalsBy(flights, (f) => f.wing, (f) => f.count);
    final sites = totalsBy(flights, (f) => f.site, (f) => f.count);
    final longest = timed.isEmpty
        ? null
        : timed.reduce(
            (a, b) =>
                flightMinutes(a.verticalOrDuration) >=
                    flightMinutes(b.verticalOrDuration)
                ? a
                : b,
          );

    return Scaffold(
      appBar: AppBar(title: const Text('Statistiques')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          SegmentedButton<Discipline?>(
            showSelectedIcon: false,
            segments: [
              for (final d in Discipline.values)
                ButtonSegment(value: d, label: Text(d.label)),
              const ButtonSegment(value: null, label: Text('Tout')),
            ],
            selected: {_discipline},
            onSelectionChanged: (s) => setState(() => _discipline = s.single),
          ),
          const SizedBox(height: 16),
          if (flights.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text('Aucun vol', textAlign: TextAlign.center),
            )
          else ...[
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.9,
              children: [
                _Tile('Vols', '$count'),
                _Tile('Sites', '${sites.length}'),
                if (showHours)
                  _Tile(
                    isParapente ? 'Heures de vol' : 'Heures de vol (parapente)',
                    formatMinutes(minutes),
                  ),
                if (isParapente) ...[
                  _Tile(
                    'Durée moyenne',
                    formatMinutes(minutes ~/ _count(timed)),
                  ),
                  _Tile(
                    'Plus long vol',
                    formatMinutes(flightMinutes(longest!.verticalOrDuration)),
                    detail:
                        '${longest.site} · ${formatNumericDate(longest.date)}',
                  ),
                ],
              ],
            ),
            _Section(
              title: isParapente ? 'Heures de vol par voile' : 'Vols par voile',
              child: Column(
                children: [
                  _Bars(
                    rows: [
                      for (final (wing, m) in _allWings ? wings : wings.take(8))
                        (
                          wing,
                          m.toDouble(),
                          isParapente
                              ? formatMinutes(m)
                              : '$m vol${m > 1 ? 's' : ''}',
                        ),
                    ],
                  ),
                  if (wings.length > 8)
                    TextButton(
                      onPressed: () => setState(() => _allWings = !_allWings),
                      child: Text(
                        _allWings
                            ? 'Voir moins'
                            : 'Voir les ${wings.length} voiles',
                      ),
                    ),
                ],
              ),
            ),
            _Section(
              title: 'Vols par mois',
              subtitle: '12 derniers mois',
              child: _MonthColumns(flights: flights),
            ),
            _Section(
              title: 'Sites les plus volés',
              child: _Bars(
                rows: [
                  for (final (site, n) in sites.take(8))
                    (site, n.toDouble(), '$n vol${n > 1 ? 's' : ''}'),
                ],
              ),
            ),
            if (showHours)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  'Vol sans durée ou « plouf » : compté 10 min.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final String label;
  final String value;
  final String? detail;

  const _Tile(this.label, this.value, {this.detail});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.accentOn(context),
              ),
            ),
            Text(
              label,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
            if (detail != null)
              Text(
                detail!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _Section({required this.title, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal bars, one per row: label, bar from a shared baseline, value.
class _Bars extends StatelessWidget {
  final List<(String, double, String)> rows;

  const _Bars({required this.rows});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final max = rows.fold(0.0, (m, r) => r.$2 > m ? r.$2 : m);
    return Column(
      children: [
        for (final (label, value, text) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 104,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) => Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: max == 0
                            ? 0
                            : (c.maxWidth * value / max).clamp(3, c.maxWidth),
                        height: 14,
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 64,
                  child: Text(
                    text,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Flights per month over the last 12 months, as columns; tapping a month
/// shows its count.
class _MonthColumns extends StatefulWidget {
  final List<FlightEntry> flights;

  const _MonthColumns({required this.flights});

  @override
  State<_MonthColumns> createState() => _MonthColumnsState();
}

class _MonthColumnsState extends State<_MonthColumns> {
  int? _selected;

  static const _initials = [
    'J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D', //
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final months = [
      for (var i = 11; i >= 0; i--) DateTime(now.year, now.month - i),
    ];
    final counts = [
      for (final m in months)
        widget.flights
            .where((f) => f.date.year == m.year && f.date.month == m.month)
            .fold(0, (sum, f) => sum + f.count),
    ];
    final max = counts.fold(0, (a, b) => a > b ? a : b);
    final selected = _selected;
    const height = 120.0;

    return Column(
      children: [
        SizedBox(
          height: 20,
          child: Text(
            selected == null
                ? (max == 0 ? 'Aucun vol' : 'Touche un mois')
                : '${formatMonthYear(months[selected])} : '
                      '${counts[selected]} vol${counts[selected] > 1 ? 's' : ''}',
            style: TextStyle(
              fontSize: 12,
              color: selected == null ? cs.onSurfaceVariant : cs.onSurface,
              fontWeight: selected == null ? null : FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: height + 20,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < months.length; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () =>
                        setState(() => _selected = _selected == i ? null : i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          height: max == 0
                              ? 0
                              : (height * counts[i] / max).clamp(
                                  counts[i] == 0 ? 0 : 3,
                                  height,
                                ),
                          decoration: BoxDecoration(
                            color: _selected == null || _selected == i
                                ? AppColors.accent
                                : AppColors.accent.withValues(alpha: 0.35),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ),
                        // Baseline.
                        Container(height: 1, color: cs.outlineVariant),
                        const SizedBox(height: 4),
                        Text(
                          _initials[months[i].month - 1],
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
