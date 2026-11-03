import 'package:flutter/material.dart';

import '../models/run_location.dart';
import '../screens/location_picker_screen.dart';
import '../theme/app_colors.dart';
import '../utils/latlng_parser.dart';
import 'page_colors.dart';

/// Edits the takeoff and landing of a site (empty [run]) or of one of its
/// runs: on the map or as pasted "lat, lon" text. Pops the [RunLocation].
class LocationEditDialog extends StatefulWidget {
  final String site;
  final String run;
  final RunLocation? existing;
  final LatLngPair? fallbackCenter;

  const LocationEditDialog({
    super.key,
    required this.site,
    required this.run,
    this.existing,
    this.fallbackCenter,
  });

  @override
  State<LocationEditDialog> createState() => _LocationEditDialogState();
}

class _LocationEditDialogState extends State<LocationEditDialog> {
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
