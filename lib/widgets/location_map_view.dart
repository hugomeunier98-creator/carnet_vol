import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart' deferred as fm;
import 'package:latlong2/latlong.dart' deferred as ll;
import 'package:share_plus/share_plus.dart';

import '../models/run_location.dart';
import '../utils/latlng_parser.dart';

// flutter_map/latlong2 are only needed on this one screen when a flight
// actually has GPS coordinates - deferred-loading them keeps the initial
// app bundle smaller and avoids fetching/parsing this code at startup.
class LocationMapView extends StatefulWidget {
  final RunLocation location;
  final VoidCallback onEdit;

  const LocationMapView({super.key, required this.location, required this.onEdit});

  @override
  State<LocationMapView> createState() => _LocationMapViewState();
}

class _LocationMapViewState extends State<LocationMapView> {
  bool _ready = false;
  Object? _error;

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

  Future<void> _showCoordActions(
    BuildContext context,
    Offset globalPosition,
    String label,
    double lat,
    double lng,
  ) async {
    final text = formatLatLng(lat, lng);
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        globalPosition & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: const [
        PopupMenuItem(
          value: 'copy',
          child: Row(children: [
            Icon(Icons.copy, size: 18),
            SizedBox(width: 8),
            Text('Copier les coordonnées'),
          ]),
        ),
        PopupMenuItem(
          value: 'share',
          child: Row(children: [
            Icon(Icons.ios_share, size: 18),
            SizedBox(width: 8),
            Text('Partager'),
          ]),
        ),
      ],
    );
    if (!context.mounted || selected == null) return;
    if (selected == 'copy') {
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$label copié : $text')));
      }
    } else if (selected == 'share') {
      await SharePlus.instance.share(ShareParams(text: text, subject: label));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text("Impossible de charger la carte"),
      );
    }
    if (!_ready) {
      return const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final loc = widget.location;
    // ll.LatLng is a deferred type, so it can't appear in an explicit
    // declaration - `dynamic` sidesteps that while still being a real
    // LatLng at runtime (the library is guaranteed loaded by now).
    final List<dynamic> points = [
      if (loc.hasTakeoff) ll.LatLng(loc.takeoffLat!, loc.takeoffLng!),
      if (loc.hasLanding) ll.LatLng(loc.landingLat!, loc.landingLng!),
    ];
    final centerLat = points.map((p) => p.latitude as double).reduce((a, b) => a + b) / points.length;
    final centerLng = points.map((p) => p.longitude as double).reduce((a, b) => a + b) / points.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 220,
            child: fm.FlutterMap(
              options: fm.MapOptions(
                initialCenter: ll.LatLng(centerLat, centerLng),
                initialZoom: points.length > 1 ? 12 : 13,
                interactionOptions: fm.InteractionOptions(
                  flags: fm.InteractiveFlag.pinchZoom | fm.InteractiveFlag.drag,
                ),
              ),
              children: [
                fm.TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.hugomeunier.carnet_vol',
                ),
                fm.MarkerLayer(
                  markers: [
                    if (loc.hasTakeoff)
                      fm.Marker(
                        point: ll.LatLng(loc.takeoffLat!, loc.takeoffLng!),
                        width: 36,
                        height: 36,
                        child: GestureDetector(
                          onTapDown: (details) => _showCoordActions(
                            context,
                            details.globalPosition,
                            'Décollage',
                            loc.takeoffLat!,
                            loc.takeoffLng!,
                          ),
                          child: const Icon(Icons.flight_takeoff, color: Colors.green, size: 32),
                        ),
                      ),
                    if (loc.hasLanding)
                      fm.Marker(
                        point: ll.LatLng(loc.landingLat!, loc.landingLng!),
                        width: 36,
                        height: 36,
                        child: GestureDetector(
                          onTapDown: (details) => _showCoordActions(
                            context,
                            details.globalPosition,
                            'Atterrissage',
                            loc.landingLat!,
                            loc.landingLng!,
                          ),
                          child: const Icon(Icons.flight_land, color: Colors.redAccent, size: 32),
                        ),
                      ),
                  ],
                ),
                fm.RichAttributionWidget(
                  attributions: [
                    fm.TextSourceAttribution(
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
            onPressed: widget.onEdit,
            icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
            label: const Text('Modifier les coordonnées'),
          ),
        ),
      ],
    );
  }
}
