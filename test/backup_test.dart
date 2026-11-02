import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carnet_vol/models/discipline.dart';
import 'package:carnet_vol/models/flight_entry.dart';
import 'package:carnet_vol/models/run_location.dart';
import 'package:carnet_vol/services/backup_service.dart';

void main() {
  test('a backup restores flights, GPS points and names', () async {
    SharedPreferences.setMockInitialValues({});
    final service = BackupService();
    final original = Backup(
      flights: [
        FlightEntry(
          id: 'p1',
          discipline: Discipline.parapente,
          date: DateTime(2026, 9, 22),
          site: 'Planfait',
          wing: 'Rush 6',
          comment: 'Thermique',
        ),
      ],
      runLocations: const [
        RunLocation(site: 'Planfait', run: '', takeoffLat: 45.9, takeoffLng: 6.2),
      ],
      sites: ['Planfait'],
      runs: [],
      wings: ['Rush 6'],
    );

    final parsed = Backup.tryParse(original.toJson())!;
    await service.restore(parsed);
    final loaded = await service.load();

    expect(loaded.flights.single.discipline, Discipline.parapente);
    expect(loaded.flights.single.comment, 'Thermique');
    expect(loaded.runLocations.single.takeoffLat, 45.9);
    expect(loaded.sites, ['Planfait']);
    expect(loaded.wings, ['Rush 6']);
  });

  test('a plain flight export is not taken for a backup', () {
    expect(Backup.tryParse('[{"id": "x"}]'), isNull);
    expect(Backup.tryParse('not json'), isNull);
  });
}
