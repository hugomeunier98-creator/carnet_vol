import 'package:carnet_vol/models/run_location.dart';
import 'package:carnet_vol/utils/run_locations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const site = RunLocation(site: 'Salève', run: '', takeoffLat: 46.1, takeoffLng: 6.2);
  const run = RunLocation(site: 'Salève', run: 'Pitons', takeoffLat: 46.0, takeoffLng: 6.1);

  test('a run uses its own points, else those of its site', () {
    expect(locationFor([site, run], 'Salève', 'Pitons'), run);
    expect(locationFor([site], 'Salève', 'Pitons'), site);
    expect(locationFor([site], 'Salève', ''), site);
    expect(locationFor([run], 'Salève', ''), isNull);
    expect(locationFor([site], 'Forclaz', ''), isNull);
  });

  test('upsertLocation replaces the same site and run, else adds', () {
    const moved = RunLocation(site: 'Salève', run: '', landingLat: 46.2, landingLng: 6.3);
    expect(upsertLocation([site, run], moved), [moved, run]);
    expect(upsertLocation([run], moved), [run, moved]);
  });
}
