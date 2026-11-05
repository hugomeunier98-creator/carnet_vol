import 'package:carnet_vol/models/flight_entry.dart';
import 'package:carnet_vol/models/run_location.dart';
import 'package:carnet_vol/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

FlightEntry flight(String id, String site, String run) => FlightEntry(
  id: id,
  date: DateTime(2024, 5, 9),
  site: site,
  run: run,
  wing: 'Mirage 13',
);

void main() {
  test('Chartreuse runs become the sites', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.saveFlights([
      flight('a', 'Chartreuse', 'Saint Hilaire'),
      flight('b', 'Chartreuse', 'Pravouta'),
      flight('c', 'Chartreuse', 'Dent de Crolles'),
      flight('d', 'Semnoz', ''),
    ]);
    await storage.saveSites([
      'Chartreuse',
      'Dent de Crolles',
      'Saint Hilaire',
      'Semnoz',
    ]);
    const mine = RunLocation(
      site: 'Dent de Crolles',
      run: '',
      takeoffLat: 1,
      takeoffLng: 2,
    );
    const chartreuse = RunLocation(
      site: 'Chartreuse',
      run: 'Dent de Crolles',
      takeoffLat: 3,
      takeoffLng: 4,
    );
    await storage.saveRunLocations([chartreuse, mine]);

    await storage.applyDataFixes();

    final flights = await storage.loadFlights();
    expect(flights.map((f) => (f.site, f.run)), [
      ('Saint Hilaire', ''),
      ('Pravouta', ''),
      ('Dent de Crolles', ''),
      ('Semnoz', ''),
    ]);
    expect(await storage.loadSites(), [
      'Dent de Crolles',
      'Pravouta',
      'Saint Hilaire',
      'Semnoz',
    ]);
    final locations = await storage.loadRunLocations();
    expect(locations.single.takeoffLat, 1);
  });
}
