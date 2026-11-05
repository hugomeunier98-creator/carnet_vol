import '../models/run_location.dart';

/// Flying sites the app ships with, with their takeoff and landing. Added
/// once to the stored sites (see StorageService.seedPresetSites); points
/// already set for the same site and run are kept.
const presetSites = <RunLocation>[
  RunLocation(
    site: 'Petit Taillefer',
    run: '',
    takeoffLat: 45.04236,
    takeoffLng: 5.88821,
    landingLat: 45.06346,
    landingLng: 5.86799,
  ),
  RunLocation(
    site: 'Val d’Isere',
    run: 'Solaise',
    takeoffLat: 45.43213,
    takeoffLng: 6.99166,
    landingLat: 45.4375708,
    landingLng: 6.9770352,
  ),
  RunLocation(
    site: 'Col des Fretes',
    run: '',
    takeoffLat: 45.8563675,
    takeoffLng: 6.2463669,
    landingLat: 45.8486057,
    landingLng: 6.2138257,
  ),
  RunLocation(
    site: 'Mont-Blanc',
    run: '',
    takeoffLat: 45.83264,
    takeoffLng: 6.86518,
    landingLat: 45.9296,
    landingLng: 6.87642,
  ),
  RunLocation(
    site: 'Dent de Crolles',
    run: '',
    takeoffLat: 45.30938,
    takeoffLng: 5.85709,
    landingLat: 45.30222,
    landingLng: 5.90627,
  ),
  RunLocation(
    site: 'Saleve',
    run: '',
    takeoffLat: 46.1348,
    takeoffLng: 6.17315,
    landingLat: 46.13372,
    landingLng: 6.16069,
  ),
  RunLocation(
    site: 'Tournette',
    run: '',
    takeoffLat: 45.81866,
    takeoffLng: 6.28948,
    landingLat: 45.84874,
    landingLng: 6.21393,
  ),
  RunLocation(
    site: 'Planfait',
    run: '',
    takeoffLat: 45.85319,
    takeoffLng: 6.22296,
    landingLat: 45.84859,
    landingLng: 6.21363,
  ),
  RunLocation(
    site: 'Rismålheia',
    run: '',
    takeoffLat: 69.55362,
    takeoffLng: 18.37416,
    landingLat: 69.53249,
    landingLng: 18.35958,
  ),
  RunLocation(
    site: 'Semnoz',
    run: '',
    takeoffLat: 45.8058,
    takeoffLng: 6.09603,
    landingLat: 45.81241,
    landingLng: 6.05248,
  ),
  RunLocation(
    site: 'Koh Larn',
    run: '',
    takeoffLat: 12.90795,
    takeoffLng: 100.77516,
    landingLat: 12.908,
    landingLng: 100.7745,
  ),
  RunLocation(
    site: 'Grand Bornand',
    run: '',
    takeoffLat: 45.95843,
    takeoffLng: 6.47656,
    landingLat: 45.93558,
    landingLng: 6.46196,
  ),
  RunLocation(
    site: 'Éléphants',
    run: '',
    takeoffLat: 13.16293,
    takeoffLng: 101.4171,
    landingLat: 13.15281,
    landingLng: 101.41604,
  ),
  RunLocation(
    site: 'Forclaz',
    run: '',
    takeoffLat: 45.81413,
    takeoffLng: 6.24688,
    landingLat: 45.78106,
    landingLng: 6.22177,
  ),
  RunLocation(
    site: 'Taillefer',
    run: '',
    takeoffLat: 45.04184,
    takeoffLng: 5.88967,
    landingLat: 45.0633,
    landingLng: 5.86781,
  ),
  RunLocation(
    site: 'Quintal',
    run: '',
    takeoffLat: 45.83997,
    takeoffLng: 6.09765,
    landingLat: 45.8394,
    landingLng: 6.08847,
  ),
];

/// [stored] plus the [presets] whose site and run have no points yet.
List<RunLocation> withPresets(
  List<RunLocation> stored, [
  List<RunLocation> presets = presetSites,
]) => [
  ...stored,
  for (final p in presets)
    if (!stored.any((l) => l.matches(p.site, p.run))) p,
];
