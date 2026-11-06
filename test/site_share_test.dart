import 'package:carnet_vol/models/run_location.dart';
import 'package:carnet_vol/utils/site_share.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('site message lists takeoff and landing as lat, lon', () {
    const loc = RunLocation(
      site: 'Planfait',
      run: '',
      takeoffLat: 45.85319,
      takeoffLng: 6.22296,
      landingLat: 45.84859,
      landingLng: 6.21363,
    );
    expect(
      siteShareText('Planfait', '', loc),
      'Site: Planfait\n'
      'Deco: 45.85319, 6.22296\n'
      'Atterro: 45.84859, 6.21363',
    );
  });

  test('a run is named, missing points are left out', () {
    const loc = RunLocation(
      site: 'Val d’Isere',
      run: 'Solaise',
      takeoffLat: 45.43213,
      takeoffLng: 6.99166,
    );
    expect(
      siteShareText('Val d’Isere', 'Solaise', loc),
      'Site: Val d’Isere\nRun: Solaise\nDeco: 45.43213, 6.99166',
    );
  });
}
