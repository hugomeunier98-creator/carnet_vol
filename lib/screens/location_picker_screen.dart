import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' deferred as fm;
import 'package:latlong2/latlong.dart' deferred as ll;

import '../utils/latlng_parser.dart';

typedef LatLngPair = (double, double);

/// Takeoff/landing chosen on the map; either may be left empty.
typedef PickedLocation = ({LatLngPair? takeoff, LatLngPair? landing});

enum _Point { takeoff, landing }

enum _Layer { plan, topo, satellite }

/// Full-screen map where tapping places the takeoff or landing point.
/// flutter_map/latlong2 are deferred, as in LocationMapView.
class LocationPickerScreen extends StatefulWidget {
  final String title;
  final LatLngPair? takeoff;
  final LatLngPair? landing;

  /// Where to look first when neither point is set yet (e.g. another run of
  /// the same site); null falls back to a wide view of the Alps.
  final LatLngPair? fallbackCenter;

  const LocationPickerScreen({
    super.key,
    required this.title,
    this.takeoff,
    this.landing,
    this.fallbackCenter,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  static const _alps = (46.0, 7.0);

  bool _ready = false;
  Object? _error;
  late LatLngPair? _takeoff = widget.takeoff;
  late LatLngPair? _landing = widget.landing;
  late _Point _editing =
      widget.takeoff != null && widget.landing == null ? _Point.landing : _Point.takeoff;
  _Layer _layer = _Layer.topo;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await Future.wait([fm.loadLibrary(), ll.loadLibrary()]);
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _place(double lat, double lng) {
    setState(() {
      if (_editing == _Point.takeoff) {
        _takeoff = (lat, lng);
        // Placing the takeoff of a new site usually comes first: move on.
        if (_landing == null) _editing = _Point.landing;
      } else {
        _landing = (lat, lng);
      }
    });
  }

  dynamic _tileLayer() {
    switch (_layer) {
      case _Layer.plan:
        return fm.TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.hugomeunier.carnet_vol',
        );
      case _Layer.topo:
        return fm.TileLayer(
          urlTemplate: 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c'],
          maxNativeZoom: 17,
          userAgentPackageName: 'com.hugomeunier.carnet_vol',
        );
      case _Layer.satellite:
        return fm.TileLayer(
          urlTemplate:
              'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
          maxNativeZoom: 19,
          userAgentPackageName: 'com.hugomeunier.carnet_vol',
        );
    }
  }

  String get _attribution => switch (_layer) {
        _Layer.plan => '© OpenStreetMap contributors',
        _Layer.topo => '© OpenStreetMap contributors, SRTM · © OpenTopoMap (CC-BY-SA)',
        _Layer.satellite => 'Imagerie © Esri, Maxar, Earthstar Geographics',
      };

  dynamic _initialOptions() {
    final points = [?_takeoff, ?_landing];
    void onTap(dynamic _, dynamic point) =>
        _place(point.latitude as double, point.longitude as double);
    final interaction = fm.InteractionOptions(
      flags: fm.InteractiveFlag.all & ~fm.InteractiveFlag.rotate,
    );
    if (points.length == 2) {
      return fm.MapOptions(
        initialCameraFit: fm.CameraFit.coordinates(
          coordinates: [for (final p in points) ll.LatLng(p.$1, p.$2)],
          padding: const EdgeInsets.fromLTRB(60, 120, 60, 200),
          maxZoom: 15,
        ),
        interactionOptions: interaction,
        onTap: onTap,
      );
    }
    final center = points.isNotEmpty ? points.first : widget.fallbackCenter ?? _alps;
    final zoom = points.isNotEmpty
        ? 14.0
        : widget.fallbackCenter != null
            ? 13.0
            : 8.0;
    return fm.MapOptions(
      initialCenter: ll.LatLng(center.$1, center.$2),
      initialZoom: zoom,
      interactionOptions: interaction,
      onTap: onTap,
    );
  }

  dynamic _marker(LatLngPair p, IconData icon, Color color) => fm.Marker(
        point: ll.LatLng(p.$1, p.$2),
        width: 40,
        height: 40,
        child: Icon(icon, color: color, size: 36, shadows: const [
          Shadow(color: Colors.white, blurRadius: 6),
        ]),
      );

  Widget _map() {
    if (_error != null) {
      return const Center(child: Text('Impossible de charger la carte'));
    }
    if (!_ready) return const Center(child: CircularProgressIndicator());
    return fm.FlutterMap(
      options: _initialOptions(),
      children: [
        _tileLayer(),
        fm.MarkerLayer(markers: [
          if (_takeoff != null) _marker(_takeoff!, Icons.flight_takeoff, Colors.green.shade700),
          if (_landing != null) _marker(_landing!, Icons.flight_land, Colors.red.shade600),
        ]),
        fm.RichAttributionWidget(
          alignment: fm.AttributionAlignment.bottomLeft,
          attributions: [fm.TextSourceAttribution(_attribution)],
        ),
      ],
    );
  }

  Widget _pointRow(_Point point, String label, IconData icon, Color color, LatLngPair? value) {
    final selected = _editing == point;
    return ListTile(
      dense: true,
      selected: selected,
      selectedTileColor: color.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      leading: Icon(icon, color: color),
      title: Text(label),
      subtitle: Text(value == null ? 'Touchez la carte pour placer' : formatLatLng(value.$1, value.$2)),
      trailing: value == null
          ? null
          : IconButton(
              tooltip: 'Effacer',
              icon: const Icon(Icons.close),
              onPressed: () => setState(() {
                if (point == _Point.takeoff) {
                  _takeoff = null;
                } else {
                  _landing = null;
                }
                _editing = point;
              }),
            ),
      onTap: () => setState(() => _editing = point),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
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
          TextButton(
            onPressed: () => Navigator.of(context)
                .pop<PickedLocation>((takeoff: _takeoff, landing: _landing)),
            child: const Text('Valider'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _map()),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _pointRow(_Point.takeoff, 'Décollage', Icons.flight_takeoff,
                      Colors.green.shade700, _takeoff),
                  _pointRow(_Point.landing, 'Atterrissage', Icons.flight_land,
                      Colors.red.shade600, _landing),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
