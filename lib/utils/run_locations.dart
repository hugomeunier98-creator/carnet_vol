import '../models/run_location.dart';
import '../screens/location_picker_screen.dart';

/// Location of a flight: its run's own points, else those of the site
/// (stored with an empty run, e.g. set from "Sites & runs").
RunLocation? locationFor(List<RunLocation> all, String site, String run) {
  RunLocation? find(String r) {
    for (final l in all) {
      if (l.matches(site, r) && l.hasAny) return l;
    }
    return null;
  }

  return find(run) ?? (run.isEmpty ? null : find(''));
}

/// [all] with [location] replacing the entry of the same site and run.
List<RunLocation> upsertLocation(List<RunLocation> all, RunLocation location) {
  final result = List<RunLocation>.of(all);
  final idx = result.indexWhere((l) => l.matches(location.site, location.run));
  if (idx >= 0) {
    result[idx] = location;
  } else {
    result.add(location);
  }
  return result;
}

/// Where the map picker starts when nothing is placed yet: a located run
/// of [site], else the last located place.
LatLngPair? fallbackCenterFor(List<RunLocation> all, String site) {
  LatLngPair? firstPoint(RunLocation l) => l.hasTakeoff
      ? (l.takeoffLat!, l.takeoffLng!)
      : l.hasLanding
      ? (l.landingLat!, l.landingLng!)
      : null;
  final located = all.where((l) => l.hasAny).toList();
  for (final l in located) {
    if (l.site == site) return firstPoint(l);
  }
  return located.isEmpty ? null : firstPoint(located.last);
}
