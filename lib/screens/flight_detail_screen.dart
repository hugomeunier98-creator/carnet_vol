import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/flight_entry.dart';
import '../models/run_location.dart';
import '../services/storage_service.dart';
import '../utils/flight_numbering.dart';
import '../utils/latlng_parser.dart';
import '../widgets/media_section.dart';
import 'flight_form_screen.dart';

class FlightDetailScreen extends StatefulWidget {
  final FlightEntry entry;
  final List<FlightEntry> allFlights;
  final List<String> knownSites;
  final List<String> knownRuns;
  final List<String> knownWings;
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

  Future<void> _editLocation() async {
    final result = await showDialog<RunLocation>(
      context: context,
      builder: (context) => _LocationEditDialog(
        site: _entry.site,
        run: _entry.run,
        existing: _location,
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
    final dateStr =
        '${e.date.day.toString().padLeft(2, '0')}/${e.date.month.toString().padLeft(2, '0')}/${e.date.year}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail du vol'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Modifier',
            onPressed: _editFlight,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HeaderCard(entry: e, dateStr: dateStr, numberLabel: _numberLabel),
          const SizedBox(height: 20),
          Text('Commentaire', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            e.comment.isNotEmpty ? e.comment : 'Pas de commentaire',
            style: e.comment.isEmpty
                ? Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontStyle: FontStyle.italic, color: Colors.grey.shade600)
                : Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Text('Localisation', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(e.run.isNotEmpty ? '${e.site} · ${e.run}' : e.site),
          const SizedBox(height: 12),
          if (_loadingLocation)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            _LocationMap(location: _location, onEdit: _editLocation),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),
          MediaSection(flightId: e.id),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final FlightEntry entry;
  final String dateStr;
  final String? numberLabel;

  const _HeaderCard({required this.entry, required this.dateStr, required this.numberLabel});

  @override
  Widget build(BuildContext context) {
    final onColor = Theme.of(context).colorScheme.onPrimaryContainer;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(dateStr,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(color: onColor, fontWeight: FontWeight.bold)),
              if (numberLabel != null)
                Text(numberLabel!,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: onColor)),
            ],
          ),
          const SizedBox(height: 4),
          Text(entry.wing, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: onColor)),
        ],
      ),
    );
  }
}

class _LocationMap extends StatelessWidget {
  final RunLocation? location;
  final VoidCallback onEdit;

  const _LocationMap({required this.location, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final loc = location;
    if (loc == null || !loc.hasAny) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(Icons.map_outlined, size: 32, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            const Text('Aucune coordonnée GPS pour ce run'),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Ajouter les coordonnées GPS'),
            ),
          ],
        ),
      );
    }

    final points = <LatLng>[
      if (loc.hasTakeoff) LatLng(loc.takeoffLat!, loc.takeoffLng!),
      if (loc.hasLanding) LatLng(loc.landingLat!, loc.landingLng!),
    ];
    final centerLat = points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length;
    final centerLng = points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 220,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(centerLat, centerLng),
                initialZoom: points.length > 1 ? 12 : 13,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.hugomeunier.carnet_vol',
                ),
                MarkerLayer(
                  markers: [
                    if (loc.hasTakeoff)
                      Marker(
                        point: LatLng(loc.takeoffLat!, loc.takeoffLng!),
                        width: 36,
                        height: 36,
                        child: const Icon(Icons.flight_takeoff, color: Colors.green, size: 32),
                      ),
                    if (loc.hasLanding)
                      Marker(
                        point: LatLng(loc.landingLat!, loc.landingLng!),
                        width: 36,
                        height: 36,
                        child: const Icon(Icons.flight_land, color: Colors.redAccent, size: 32),
                      ),
                  ],
                ),
                RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution(
                      '© OpenStreetMap contributors',
                      onTap: () {},
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
            label: const Text('Modifier les coordonnées'),
          ),
        ),
      ],
    );
  }
}

class _LocationEditDialog extends StatefulWidget {
  final String site;
  final String run;
  final RunLocation? existing;

  const _LocationEditDialog({required this.site, required this.run, this.existing});

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
    _takeoff = TextEditingController(text: formatLatLng(e?.takeoffLat, e?.takeoffLng));
    _landing = TextEditingController(text: formatLatLng(e?.landingLat, e?.landingLng));
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
      title: Text(widget.run.isNotEmpty ? '${widget.site} · ${widget.run}' : widget.site),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Colle une position au format "lat, lon" (ex: depuis Google Maps ou Apple Plans).',
            ),
            const SizedBox(height: 16),
            _coordField(label: 'Décollage', controller: _takeoff, errorText: _takeoffError),
            const SizedBox(height: 16),
            _coordField(label: 'Atterrissage', controller: _landing, errorText: _landingError),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
        FilledButton(onPressed: _save, child: const Text('Enregistrer')),
      ],
    );
  }
}
