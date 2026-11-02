import 'package:flutter_test/flutter_test.dart';
import 'package:carnet_vol/models/discipline.dart';
import 'package:carnet_vol/services/export_service.dart';

const header = 'Nº\tDate\tDéco\tDurée\tVoile\n';
const rows = '1\t12/06/24\tPlanfait\t45min\tRush 6\n'
    '2-3\t\tForclaz\t20min\tRush 6\n'
    '4\t03/07/2024\tMontmin\t1h30\tZeno 2\n';

void main() {
  final export = ExportService();

  void expectParapenteRows(List result) {
    expect(result.length, 3);
    final first = result.first;
    expect(first.discipline, Discipline.parapente);
    expect(first.date, DateTime(2024, 6, 12));
    expect(first.site, 'Planfait');
    expect(first.run, '');
    expect(first.verticalOrDuration, '45min');
    expect(first.wing, 'Rush 6');

    expect(result[1].count, 2);
    expect(result[1].date, DateTime(2024, 6, 12));
    expect(result[1].site, 'Forclaz');

    expect(result[2].wing, 'Zeno 2');
    expect(result[2].verticalOrDuration, '1h30');
  }

  test('parapente table: columns found from the header row', () {
    expectParapenteRows(export.parseNotesTable(header + rows, Discipline.parapente));
  });

  test('parapente table pasted without its header uses the parapente layout', () {
    expectParapenteRows(export.parseNotesTable(rows, Discipline.parapente));
  });

  test('header row wins over the discipline default layout', () {
    // A parapente-shaped table imported while on the speedflying tab.
    final result = export.parseNotesTable(header + rows, Discipline.speedflying);
    expect(result.first.wing, 'Rush 6');
    expect(result.first.verticalOrDuration, '45min');
    expect(result.first.run, '');
  });
}
