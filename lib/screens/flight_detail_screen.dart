import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../models/discipline.dart';
import '../models/flight_entry.dart';
import '../widgets/discipline_icon.dart';
import '../widgets/page_colors.dart';
import '../models/run_location.dart';
import '../services/storage_service.dart';
import '../utils/date_format.dart';
import '../utils/flight_numbering.dart';
import '../utils/run_locations.dart';
import '../widgets/location_edit_dialog.dart';
import '../widgets/location_map_view.dart';
import '../widgets/photos_section.dart';
import 'flight_form_screen.dart';

class FlightDetailScreen extends StatefulWidget {
  final FlightEntry entry;
  final List<FlightEntry> allFlights;
  final List<String> knownSites;
  final List<String> knownRuns;
  final Map<Discipline, List<String>> knownWings;
  final ValueChanged<FlightEntry> onUpdated;
  final VoidCallback onDeleted;

  const FlightDetailScreen({
    super.key,
    required this.entry,
    required this.allFlights,
    required this.knownSites,
    required this.knownRuns,
    required this.knownWings,
    required this.onUpdated,
    required this.onDeleted,
  });

  @override
  State<FlightDetailScreen> createState() => _FlightDetailScreenState();
}

class _FlightDetailScreenState extends State<FlightDetailScreen> {
  final _storage = StorageService();
  late FlightEntry _entry;
  late List<FlightEntry> _allFlights;
  RunLocation? _location;
  bool _loadingLocation = true;

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
    _allFlights = widget.allFlights;
    _loadLocation();
  }

  String? get _numberLabel => computeFlightNumberLabels(_allFlights)[_entry.id];

  Future<void> _loadLocation() async {
    final all = await _storage.loadRunLocations();
    if (!mounted) return;
    setState(() {
      _location = locationFor(all, _entry.site, _entry.run);
      _loadingLocation = false;
    });
  }

  Future<void> _editFlight() async {
    final result = await Navigator.of(context).push<Object>(
      MaterialPageRoute(
        builder: (_) => FlightFormScreen(
          existing: _entry,
          knownSites: widget.knownSites,
          knownRuns: widget.knownRuns,
          knownWings: widget.knownWings,
        ),
      ),
    );
    if (result == 'delete') {
      widget.onDeleted();
      if (mounted) Navigator.of(context).pop();
      return;
    }
    if (result is FlightEntry) {
      setState(() {
        _entry = result;
        final idx = _allFlights.indexWhere((f) => f.id == result.id);
        _allFlights = List<FlightEntry>.of(_allFlights);
        if (idx >= 0) {
          _allFlights[idx] = result;
        } else {
          _allFlights.add(result);
        }
      });
      widget.onUpdated(result);
      _loadLocation();
    }
  }

  Future<void> _editLocation() async {
    final known = await _storage.loadRunLocations();
    if (!mounted) return;
    final result = await showDialog<RunLocation>(
      context: context,
      builder: (context) => LocationEditDialog(
        site: _entry.site,
        run: _entry.run,
        existing: _location,
        fallbackCenter: fallbackCenterFor(known, _entry.site),
      ),
    );
    if (result == null) return;
    final all = await _storage.loadRunLocations();
    await _storage.saveRunLocations(upsertLocation(all, result));
    if (!mounted) return;
    setState(() => _location = result);
  }

  @override
  Widget build(BuildContext context) {
    final e = _entry;
    final cs = Theme.of(context).colorScheme;

    return PageColors(
      top: AppColors.accent,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.accent,
          title: Text(_numberLabel != null ? 'Vol $_numberLabel' : 'Vol'),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Modifier',
              onPressed: _editFlight,
            ),
            const SizedBox(width: 4),
          ],
        ),
        // The hero stays joined to the app bar, as one block: the cards
        // scroll (and bounce) underneath it.
        body: Stack(
          children: [
            ListView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                // Room for the hero, drawn on top.
                Visibility(
                  visible: false,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: _HeroCard(entry: e),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Section(
                        icon: Icons.chat_bubble_outline,
                        title: 'Commentaire',
                        child: InkWell(
                          onTap: _editFlight,
                          borderRadius: BorderRadius.circular(8),
                          child: Text(
                            e.comment.isNotEmpty
                                ? e.comment
                                : 'Aucun commentaire · toucher pour en ajouter',
                            style: e.comment.isEmpty
                                ? TextStyle(
                                    color: cs.onSurfaceVariant,
                                    fontStyle: FontStyle.italic,
                                  )
                                : Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _Section(
                        icon: Icons.place_outlined,
                        title: 'Localisation',
                        child: _loadingLocation
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : _location == null || !_location!.hasAny
                            ? _NoLocation(onEdit: _editLocation)
                            : LocationMapView(
                                location: _location!,
                                onEdit: _editLocation,
                              ),
                      ),
                      const SizedBox(height: 12),
                      _Section(
                        icon: Icons.photo_library_outlined,
                        title: 'Photos & vidéos',
                        child: PhotosSection(date: e.date),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(top: 0, left: 0, right: 0, child: _HeroCard(entry: e)),
          ],
        ),
      ),
    );
  }
}

/// Top of the flight page: where, when and with what, on the discipline's
/// colour.
class _HeroCard extends StatelessWidget {
  final FlightEntry entry;

  const _HeroCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    const base = AppColors.accent;
    final white70 = Colors.white.withValues(alpha: 0.8);

    Widget pill(Widget icon, String text) => Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 22),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        gradient: LinearGradient(
          colors: [base, Color.lerp(base, Colors.black, 0.25)!],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          pill(
            DisciplineIcon(entry.discipline, size: 16, color: Colors.white),
            entry.discipline.label,
          ),
          const SizedBox(height: 14),
          Text(
            entry.site,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.1,
              letterSpacing: -0.5,
            ),
          ),
          if (entry.run.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              entry.run,
              style: TextStyle(
                color: white70,
                fontSize: 17,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.calendar_today_outlined, size: 16, color: white70),
              const SizedBox(width: 6),
              Text(
                formatLongDate(entry.date),
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (entry.wing.isNotEmpty)
                pill(
                  const Icon(Icons.paragliding, size: 16, color: Colors.white),
                  entry.wing,
                ),
              if (entry.verticalOrDuration.isNotEmpty)
                entry.discipline == Discipline.speedflying &&
                        entry.verticalMeters != null
                    ? pill(
                        const Icon(
                          Icons.trending_down,
                          size: 16,
                          color: Colors.white,
                        ),
                        '${entry.verticalOrDuration}'
                        '${'${entry.verticalMeters}' == entry.verticalOrDuration.trim() ? ' m' : ''}',
                      )
                    : pill(
                        const Icon(
                          Icons.timer_outlined,
                          size: 16,
                          color: Colors.white,
                        ),
                        entry.verticalOrDuration,
                      ),
              if (entry.count > 1)
                pill(
                  const Icon(Icons.repeat, size: 16, color: Colors.white),
                  '${entry.count} vols',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A titled card grouping one aspect of the flight.
class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _Section({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _NoLocation extends StatelessWidget {
  final VoidCallback onEdit;

  const _NoLocation({required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Aucune coordonnée GPS pour ce run.',
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: onEdit,
          icon: const Icon(Icons.add_location_alt_outlined),
          label: const Text('Ajouter le décollage et l\'atterrissage'),
        ),
      ],
    );
  }
}
