import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' deferred as fm;
import 'package:latlong2/latlong.dart' deferred as ll;

import '../models/flight_entry.dart';
import '../models/run_location.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import '../utils/latlng_parser.dart';
import '../utils/run_locations.dart';
import '../utils/site_share.dart';
import '../widgets/share_site_sheet.dart';
import 'location_picker_screen.dart' show LatLngPair;
import '../widgets/spot_marker.dart';

enum _Layer { topo, satellite, plan }

/// A flown site (or speedflying run) with GPS points.
class _FlownPlace {
  final String site;
  final String run;
  final RunLocation location;
  int flights = 0;

  _FlownPlace(this.site, this.run, this.location);

  String get name => run.isEmpty ? site : '$site · $run';

  /// Where the single pin goes when its two points overlap.
  LatLngPair get pin => location.hasTakeoff
      ? (location.takeoffLat!, location.takeoffLng!)
      : (location.landingLat!, location.landingLng!);
}

/// World map of every flown site with GPS points: takeoff and landing
/// markers, merged into a single pin when the map is zoomed out so far
/// that they overlap. Opens framed on all the sites.
/// flutter_map/latlong2 are deferred, as in LocationMapView.
class SitesMapScreen extends StatefulWidget {
  final List<FlightEntry> flights;

  const SitesMapScreen({super.key, required this.flights});

  @override
  State<SitesMapScreen> createState() => _SitesMapScreenState();
}

class _SitesMapScreenState extends State<SitesMapScreen> {
  /// Below this distance on screen, takeoff and landing become one pin.
  static const _mergeDistance = 36.0;

  bool _ready = false;
  Object? _error;
  List<_FlownPlace> _places = [];
  double _zoom = 3;
  _Layer _layer = _Layer.topo;
  dynamic _controller;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        fm.loadLibrary(),
        ll.loadLibrary(),
        StorageService().loadRunLocations(),
      ]);
      final locations = results[2] as List<RunLocation>;
      final byKey = <String, _FlownPlace>{};
      for (final f in widget.flights) {
        final loc = locationFor(locations, f.site, f.run);
        if (loc == null) continue;
        final place = byKey.putIfAbsent(
          '${loc.site}|${loc.run}',
          () => _FlownPlace(loc.site, loc.run, loc),
        );
        place.flights += f.count;
      }
      if (!mounted) return;
      setState(() {
        _places = byKey.values.toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        _controller = fm.MapController();
        _ready = true;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  /// Web Mercator position in pixels at [zoom].
  static math.Point<double> _pixel(double lat, double lng, double zoom) {
    final size = 256 * math.pow(2, zoom);
    final x = (lng + 180) / 360 * size;
    final s = math.sin(lat * math.pi / 180);
    final y = (0.5 - math.log((1 + s) / (1 - s)) / (4 * math.pi)) * size;
    return math.Point(x, y);
  }

  bool _merged(RunLocation l) {
    if (!l.hasTakeoff || !l.hasLanding) return true;
    final a = _pixel(l.takeoffLat!, l.takeoffLng!, _zoom);
    final b = _pixel(l.landingLat!, l.landingLng!, _zoom);
    return a.distanceTo(b) < _mergeDistance;
  }

  List<dynamic> _allPoints() => [
    for (final p in _places) ...[
      if (p.location.hasTakeoff)
        ll.LatLng(p.location.takeoffLat!, p.location.takeoffLng!),
      if (p.location.hasLanding)
        ll.LatLng(p.location.landingLat!, p.location.landingLng!),
    ],
  ];

  dynamic _tileLayer() => switch (_layer) {
    _Layer.topo => fm.TileLayer(
      urlTemplate: 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
      subdomains: const ['a', 'b', 'c'],
      maxNativeZoom: 17,
      userAgentPackageName: 'com.hugomeunier.carnet_vol',
    ),
    _Layer.satellite => fm.TileLayer(
      urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
      maxNativeZoom: 19,
      userAgentPackageName: 'com.hugomeunier.carnet_vol',
    ),
    _Layer.plan => fm.TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.hugomeunier.carnet_vol',
    ),
  };

  String get _attribution => switch (_layer) {
    _Layer.plan => '© OpenStreetMap contributors',
    _Layer.topo =>
      '© OpenStreetMap contributors, SRTM · © OpenTopoMap (CC-BY-SA)',
    _Layer.satellite => 'Imagerie © Esri, Maxar, Earthstar Geographics',
  };

  void _fitAll() {
    final points = _allPoints();
    if (points.isEmpty) return;
    _controller.fitCamera(
      fm.CameraFit.coordinates(
        coordinates: [for (final p in points) p],
        padding: const EdgeInsets.all(56),
        maxZoom: 13,
      ),
    );
  }

  void _zoomTo(_FlownPlace p) {
    final l = p.location;
    _controller.fitCamera(
      fm.CameraFit.coordinates(
        coordinates: [
          if (l.hasTakeoff) ll.LatLng(l.takeoffLat!, l.takeoffLng!),
          if (l.hasLanding) ll.LatLng(l.landingLat!, l.landingLng!),
        ],
        padding: const EdgeInsets.fromLTRB(60, 100, 60, 260),
        maxZoom: 15,
      ),
    );
  }

  Future<void> _showPlace(_FlownPlace p) async {
    final cs = Theme.of(context).colorScheme;
    final l = p.location;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    p.name,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: 'Fermer',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Text(
              '${p.flights} vol${p.flights > 1 ? 's' : ''}',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            if (l.hasTakeoff)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const SpotMarker(Spot.takeoff, onMap: false),
                title: const Text('Décollage'),
                subtitle: Text(formatLatLng(l.takeoffLat, l.takeoffLng)),
              ),
            if (l.hasLanding)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const SpotMarker(Spot.landing, onMap: false),
                title: const Text('Atterrissage'),
                subtitle: Text(formatLatLng(l.landingLat, l.landingLng)),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => shareText(siteShareText(p.site, p.run, l)),
                    icon: const Icon(Icons.ios_share),
                    label: const Text('Partager'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _zoomTo(p);
                    },
                    icon: const Icon(Icons.zoom_in),
                    label: const Text('Zoomer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<dynamic> _markers() {
    dynamic marker(
      LatLngPair at,
      Widget child,
      _FlownPlace p, {
      bool pin = false,
    }) => fm.Marker(
      point: ll.LatLng(at.$1, at.$2),
      width: pin ? 40 : 30,
      height: pin ? 40 : 30,
      // A pin's tip, not its centre, sits on the place.
      alignment: pin ? Alignment.topCenter : Alignment.center,
      child: GestureDetector(onTap: () => _showPlace(p), child: child),
    );

    return [
      for (final p in _places)
        if (_merged(p.location))
          marker(
            p.pin,
            Icon(
              Icons.location_on,
              size: 40,
              color: AppColors.accent,
              shadows: const [Shadow(color: Color(0x88000000), blurRadius: 6)],
            ),
            p,
            pin: true,
          )
        else ...[
          marker(
            (p.location.landingLat!, p.location.landingLng!),
            const SpotMarker(Spot.landing, size: 30),
            p,
          ),
          marker(
            (p.location.takeoffLat!, p.location.takeoffLng!),
            const SpotMarker(Spot.takeoff, size: 30),
            p,
          ),
        ],
    ];
  }

  Widget _map() {
    if (_error != null) {
      return const Center(child: Text('Impossible de charger la carte'));
    }
    if (!_ready) return const Center(child: CircularProgressIndicator());
    final points = _allPoints();
    return Stack(
      children: [
        fm.FlutterMap(
          mapController: _controller,
          options: fm.MapOptions(
            initialCenter: ll.LatLng(30, 10),
            initialZoom: 2,
            initialCameraFit: points.isEmpty
                ? null
                : fm.CameraFit.coordinates(
                    coordinates: [for (final p in points) p],
                    padding: const EdgeInsets.all(56),
                    maxZoom: 13,
                  ),
            minZoom: 1.5,
            interactionOptions: fm.InteractionOptions(
              flags: fm.InteractiveFlag.all & ~fm.InteractiveFlag.rotate,
            ),
            onMapReady: () =>
                setState(() => _zoom = _controller.camera.zoom as double),
            onPositionChanged: (dynamic camera, bool _) {
              final zoom = camera.zoom as double;
              if ((zoom - _zoom).abs() > 0.05) setState(() => _zoom = zoom);
            },
          ),
          children: [
            _tileLayer(),
            fm.MarkerLayer(markers: [for (final m in _markers()) m]),
            fm.RichAttributionWidget(
              alignment: fm.AttributionAlignment.bottomLeft,
              attributions: [fm.TextSourceAttribution(_attribution)],
            ),
          ],
        ),
        if (_places.isEmpty)
          Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Aucun site de vol avec des coordonnées GPS.\n'
                  'Ajoute-les depuis Sites & runs.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _ready
              ? '${_places.length} site${_places.length > 1 ? 's' : ''} volé${_places.length > 1 ? 's' : ''}'
              : 'Carte',
        ),
        actions: [
          if (_ready && _places.isNotEmpty)
            IconButton(
              tooltip: 'Voir tous les sites',
              icon: const Icon(Icons.zoom_out_map),
              onPressed: _fitAll,
            ),
          PopupMenuButton<_Layer>(
            tooltip: 'Fond de carte',
            icon: const Icon(Icons.layers_outlined),
            initialValue: _layer,
            onSelected: (l) => setState(() => _layer = l),
            itemBuilder: (_) => const [
              PopupMenuItem(value: _Layer.topo, child: Text('Topographique')),
              PopupMenuItem(value: _Layer.satellite, child: Text('Satellite')),
              PopupMenuItem(value: _Layer.plan, child: Text('Plan')),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _map(),
    );
  }
}
