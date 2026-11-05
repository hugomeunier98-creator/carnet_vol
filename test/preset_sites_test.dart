import 'package:carnet_vol/data/preset_sites.dart';
import 'package:carnet_vol/models/run_location.dart';
import 'package:carnet_vol/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('withPresets keeps stored points and adds the missing presets', () {
    const mine = RunLocation(
      site: 'Planfait',
      run: '',
      takeoffLat: 1,
      takeoffLng: 2,
    );
    const preset = RunLocation(
      site: 'Semnoz',
      run: '',
      takeoffLat: 3,
      takeoffLng: 4,
    );
    const presetPlanfait = RunLocation(
      site: 'Planfait',
      run: '',
      takeoffLat: 5,
      takeoffLng: 6,
    );
    expect(withPresets([mine], [presetPlanfait, preset]), [mine, preset]);
  });

  test('presets are seeded once, with their site and run names', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.seedPresetSites();
    expect((await storage.loadRunLocations()).length, presetSites.length);
    expect(await storage.loadSites(), contains('Rismålheia'));
    expect(await storage.loadRuns(), ['Solaise']);

    // Removed by the user afterwards: not brought back.
    await storage.saveRunLocations([]);
    await storage.seedPresetSites();
    expect(await storage.loadRunLocations(), isEmpty);
  });
}
