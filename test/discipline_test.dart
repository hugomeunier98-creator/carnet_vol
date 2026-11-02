import 'package:flutter_test/flutter_test.dart';
import 'package:carnet_vol/models/discipline.dart';
import 'package:carnet_vol/models/flight_entry.dart';
import 'package:carnet_vol/services/export_service.dart';

void main() {
  final flight = FlightEntry(
    id: 'x',
    discipline: Discipline.parapente,
    date: DateTime(2026, 9, 22),
    site: 'Planfait',
    wing: 'Rush 6',
  );

  test('flights saved before disciplines existed are speedflying', () {
    final json = flight.toJson()..remove('discipline');
    expect(FlightEntry.fromJson(json).discipline, Discipline.speedflying);
  });

  test('JSON round-trip keeps the discipline', () {
    expect(FlightEntry.fromJson(flight.toJson()).discipline, Discipline.parapente);
  });

  test('CSV round-trip keeps the discipline; old CSV uses the fallback', () {
    final export = ExportService();
    final csv = export.toCsv([flight]);
    expect(export.parseCsv(csv, Discipline.speedflying).single.discipline,
        Discipline.parapente);

    const oldCsv = 'numero,date,site,run,denivele_duree,voile,nb_vols,commentaire\n'
        '1,2026-09-22,Planfait,,,Rush 6,1,\n';
    expect(export.parseCsv(oldCsv, Discipline.parapente).single.discipline,
        Discipline.parapente);
  });
}
