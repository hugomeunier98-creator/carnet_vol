import '../models/run_location.dart';
import 'latlng_parser.dart';

/// The message shared for a site (or one of its runs): its name and its
/// takeoff and landing as "lat, lon", which map apps read when pasted.
String siteShareText(String site, String run, RunLocation? location) => [
  'Site: $site',
  if (run.isNotEmpty) 'Run: $run',
  if (location?.hasTakeoff ?? false)
    'Deco: ${formatLatLng(location!.takeoffLat, location.takeoffLng)}',
  if (location?.hasLanding ?? false)
    'Atterro: ${formatLatLng(location!.landingLat, location.landingLng)}',
].join('\n');
