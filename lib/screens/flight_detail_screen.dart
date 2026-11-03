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
import '../utils/latlng_parser.dart';
import '../widgets/location_map_view.dart';
import '../widgets/photos_section.dart';
import 'flight_form_screen.dart';
import 'location_picker_screen.dart';

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
    final match = all.where((l) => l.matches(_entry.site, _entry.run));
    if (!mounted) return;
    setState(() {
      _location = match.isEmpty ? null : match.first;
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

  /// Where the map picker starts for a run with no point yet: another run
  /// of the same site if one is located, else the last located run.
  LatLngPair? _fallbackCenter(List<RunLocation> all) {
    LatLngPair? firstPoint(RunLocation l) => l.hasTakeoff
        ? (l.takeoffLat!, l.takeoffLng!)
        : l.hasLanding
        ? (l.landingLat!, l.landingLng!)
        : null;
    final located = all.where((l) => l.hasAny).toList();
    for (final l in located) {
      if (l.site == _entry.site) return firstPoint(l);
    }
    return located.isEmpty ? null : firstPoint(located.last);
  }

  Future<void> _editLocation() async {
    final known = await _storage.loadRunLocations();
    if (!mounted) return;
    final result = await showDialog<RunLocation>(
      context: context,
      builder: (context) => _LocationEditDialog(
        site: _entry.site,
        run: _entry.run,
        existing: _location,
        fallbackCenter: _fallbackCenter(known),
      ),
    );
    if (result == null) return;
    final all = await _storage.loadRunLocations();
    final idx = all.indexWhere((l) => l.matches(result.site, result.run));
    if (idx >= 0) {
      all[idx] = result;
    } else {
      all.add(result);
    }
    await _storage.saveRunLocations(all);
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
        body: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            _HeroCard(entry: e),
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
                            child: Center(child: CircularProgressIndicator()),
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

class _LocationEditDialog extends StatefulWidget {
  final String site;
  final String run;
  final RunLocation? existing;
  final LatLngPair? fallbackCenter;

  const _LocationEditDialog({
    required this.site,
    required this.run,
    this.existing,
    this.fallbackCenter,
  });

  @override
  State<_LocationEditDialog> createState() => _LocationEditDialogState();
}

class _LocationEditDialogState extends State<_LocationEditDialog> {
  late final TextEditingController _takeoff;
  late final TextEditingController _landing;
  String? _takeoffError;
  String? _landingError;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _takeoff = TextEditingController(
      text: formatLatLng(e?.takeoffLat, e?.takeoffLng),
    );
    _landing = TextEditingController(
      text: formatLatLng(e?.landingLat, e?.landingLng),
    );
  }

  @override
  void dispose() {
    _takeoff.dispose();
    _landing.dispose();
    super.dispose();
  }

  void _save() {
    final takeoff = parseLatLng(_takeoff.text);
    final landing = parseLatLng(_landing.text);
    setState(() {
      _takeoffError = _takeoff.text.trim().isNotEmpty && takeoff == null
          ? 'Format attendu : lat, lon'
          : null;
      _landingError = _landing.text.trim().isNotEmpty && landing == null
          ? 'Format attendu : lat, lon'
          : null;
    });
    if (_takeoffError != null || _landingError != null) return;

    final result = RunLocation(
      site: widget.site,
      run: widget.run,
      takeoffLat: takeoff?.$1,
      takeoffLng: takeoff?.$2,
      landingLat: landing?.$1,
      landingLng: landing?.$2,
    );
    Navigator.of(context).pop(result);
  }

  Future<void> _pickOnMap() async {
    final title = widget.run.isNotEmpty
        ? '${widget.site} · ${widget.run}'
        : widget.site;
    final picked = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PageColors(
          top: AppColors.accent,
          child: LocationPickerScreen(
            title: title,
            takeoff: parseLatLng(_takeoff.text),
            landing: parseLatLng(_landing.text),
            fallbackCenter: widget.fallbackCenter,
          ),
        ),
      ),
    );
    if (picked == null) return;
    setState(() {
      _takeoff.text = formatLatLng(picked.takeoff?.$1, picked.takeoff?.$2);
      _landing.text = formatLatLng(picked.landing?.$1, picked.landing?.$2);
      _takeoffError = null;
      _landingError = null;
    });
  }

  Widget _coordField({
    required String label,
    required TextEditingController controller,
    required String? errorText,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: 'ex: 45.4489, 6.9622',
        errorText: errorText,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.run.isNotEmpty ? '${widget.site} · ${widget.run}' : widget.site,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FilledButton.tonalIcon(
              onPressed: _pickOnMap,
              icon: const Icon(Icons.map_outlined),
              label: const Text('Placer sur la carte'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Ou colle une position au format "lat, lon" (ex: depuis Google Maps ou Apple Plans).',
            ),
            const SizedBox(height: 16),
            _coordField(
              label: 'Décollage',
              controller: _takeoff,
              errorText: _takeoffError,
            ),
            const SizedBox(height: 16),
            _coordField(
              label: 'Atterrissage',
              controller: _landing,
              errorText: _landingError,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(onPressed: _save, child: const Text('Enregistrer')),
      ],
    );
  }
}
