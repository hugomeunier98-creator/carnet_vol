import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carnet_vol/models/discipline.dart';
import 'package:carnet_vol/models/flight_entry.dart';
import 'package:carnet_vol/models/run_location.dart';
import 'package:carnet_vol/services/backup_service.dart';
import 'package:carnet_vol/services/export_service.dart';
import 'package:carnet_vol/services/storage_service.dart';

void main() {
  final export = ExportService();

  test('"Exporter en JSON" file imports back every piece of data', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.saveFlights([
      FlightEntry(
        id: 'p1',
        discipline: Discipline.parapente,
        date: DateTime(2026, 9, 22),
        site: 'Planfait',
        wing: 'Rush 6',
        verticalOrDuration: '1h30',
        comment: 'Thermique',
        sourceNumber: '3',
      ),
      FlightEntry(
        id: 's1',
        date: DateTime(2026, 9, 20),
        site: 'Planfait',
        run: 'Sommet',
        wing: 'Swoop 16',
        count: 2,
      ),
    ]);
    await storage.saveRunLocations(const [
      RunLocation(site: 'Planfait', run: 'Sommet', takeoffLat: 45.9, takeoffLng: 6.2,
          landingLat: 45.88, landingLng: 6.21),
    ]);
    await storage.saveSites(['Planfait']);
    await storage.saveRuns(['Sommet']);
    await storage.saveWings(['Rush 6', 'Swoop 16']);

    final exported = (await BackupService().load()).toJson();
    // Imported from any tab: the file's own disciplines win.
    final imported =
        export.parseImportedFile('carnet_vol_2026-11-02.json', exported, Discipline.speedflying);

    expect(imported.flights.length, 2);
    final para = imported.flights.firstWhere((f) => f.id == 'p1');
    expect(para.discipline, Discipline.parapente);
    expect(para.verticalOrDuration, '1h30');
    expect(para.comment, 'Thermique');
    expect(para.sourceNumber, '3');
    expect(imported.flights.firstWhere((f) => f.id == 's1').count, 2);
    expect(imported.runLocations.single.landingLat, 45.88);
    expect(imported.sites, ['Planfait']);
    expect(imported.runs, ['Sommet']);
    expect(imported.wings, ['Rush 6', 'Swoop 16']);
  });

  test('GPS points from an import are added or replace the same run', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.saveRunLocations(const [
      RunLocation(site: 'Planfait', run: 'Sommet', takeoffLat: 1, takeoffLng: 1),
    ]);
    await BackupService().mergeRunLocations(const [
      RunLocation(site: 'Planfait', run: 'Sommet', takeoffLat: 45.9, takeoffLng: 6.2),
      RunLocation(site: 'Montmin', run: '', takeoffLat: 45.8, takeoffLng: 6.3),
    ]);
    final all = await storage.loadRunLocations();
    expect(all.length, 2);
    expect(all.firstWhere((l) => l.site == 'Planfait').takeoffLat, 45.9);
  });

  test('older exports (JSON list of flights, CSV) still import', () {
    const oldJson = '[{"id":"x","date":"2026-01-01T00:00:00.000","site":"A","wing":"W"}]';
    final fromJson = export.parseImportedFile('old.json', oldJson, Discipline.parapente);
    expect(fromJson.flights.single.discipline, Discipline.parapente);
    expect(fromJson.runLocations, isEmpty);

    const csv = 'numero,date,site,run,denivele_duree,voile,nb_vols,commentaire\n'
        '1,2026-09-22,Planfait,,,Rush 6,1,\n';
    expect(export.parseImportedFile('vols.csv', csv, Discipline.parapente).flights.single.site,
        'Planfait');
  });

  test('a list of flights is not taken for a full export', () {
    expect(Backup.tryParse('[{"id": "x"}]'), isNull);
    expect(Backup.tryParse('not json'), isNull);
  });
}
