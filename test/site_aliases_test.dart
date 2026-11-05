import 'package:carnet_vol/data/site_aliases.dart';
import 'package:carnet_vol/models/flight_entry.dart';
import 'package:carnet_vol/models/run_location.dart';
import 'package:carnet_vol/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('other spellings map to the app name', () {
    expect(canonicalSite('Col des Frêtes'), 'Col des Fretes');
    expect(canonicalSite('Fretes'), 'Col des Fretes');
    expect(canonicalSite('col de la forclaz'), 'Forclaz');
    expect(canonicalSite('Semnoz'), 'Semnoz');
  });

  test('stored flights, names and points are renamed', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.saveFlights([
      FlightEntry(
        id: 'a',
        date: DateTime(2026, 8, 13),
        site: 'Col des Frêtes',
        wing: '',
      ),
    ]);
    await storage.saveSites(['Col des Frêtes', 'Col des Fretes', 'Semnoz']);
    const preset = RunLocation(
      site: 'Col des Fretes',
      run: '',
      takeoffLat: 1,
      takeoffLng: 2,
    );
    const mine = RunLocation(
      site: 'Fretes',
      run: '',
      takeoffLat: 3,
      takeoffLng: 4,
    );
    const forclaz = RunLocation(
      site: 'Col de la Forclaz',
      run: '',
      takeoffLat: 5,
      takeoffLng: 6,
    );
    await storage.saveRunLocations([preset, mine, forclaz]);

    await storage.applySiteAliases();

    expect((await storage.loadFlights()).single.site, 'Col des Fretes');
    expect(await storage.loadSites(), ['Col des Fretes', 'Semnoz']);
    final locations = await storage.loadRunLocations();
    expect(locations.map((l) => l.site), ['Col des Fretes', 'Forclaz']);
    expect(locations.first.takeoffLat, 1);
  });
}
