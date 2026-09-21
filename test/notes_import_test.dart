import 'package:flutter_test/flutter_test.dart';
import 'package:carnet_vol/services/export_service.dart';

const sample = '''
Carnet de vol Speedflying

Nº	Date	Lieu	Run	Dénivelé / Durée	Voile
1	21/05/23	Vercors 	l’Aigle	100	Swoop 16
2-3		Vercors	l’Aigle	300	Swoop 16
4	23/05/23	Taillefer	Petit Taillefer	1800	Swoop 16
5	24/05/23	Chartreuse	St Hilaire 	800	Swoop 16
6-8	26/05/23	Vercors	l’Aigle	100	Swoop 16
9		Vercors	l’Aigle	300	Swoop 16
10-12	28/05/23	Chartreuse	St Hilaire 	800	Swoop 16
13	29/05/23	Chartreuse	Dent de Crolles	1800	Swoop 16
14-15		Chartreuse	St Hilaire	800	Swoop 16
16	30/05/23	Chartreuse	Le Pravouta	1200	Swoop 16
17		Chartreuse	St Hilaire	800	Swoop 16
18	11/06/23	Tegernsee	Wallberg	850	Swoop 16
19	14/07/23	Lenggries	Brauneck E	830	Swoop 16
20		Lenggries	Brauneck S	830	Swoop 16
21	20/07/23	Lenggries	Brauneck E	830	Swoop 16
22	12/08/23	Bretagne	Conquet	soaring	Swoop 16
23	16/07/23	Bretagne	Plouguerneau	soaring	biplace
24-26	04/09/23	Lenggries	Brauneck E	830	Mirage 13
27	16/09/23	Garmisch 	Osterfelderkopf N	1300	Mirage 13
28	20/09/23	Lenggries	Brauneck E	830	Mirage 13
29-30	20/09/23	Lenggries	Brauneck E	830	Mirage 13
31	28/10/23	Chamonix	Passy	750	Flame 13
32	29/10/23	Chamonix	Glacier du Tour	1400	Mirage 13
33	31/10/23	Chamonix	Planpraz 	1000	Mirage 13
34-43	03/02/24	Valfrejus 	Valfrejus	700	Mirage 13
44-46	04/02/24	Belledonne	7 Laux	600	Mirage 13
47-51	09/05/24	Chartreuse	St Hilaire 	800	Mirage 13
52-55	10/05/24	Chartreuse	St Hilaire 	800	Mirage 13
56-58	26/07/24	Val d’Isere	Solaise	600	Mirage 13
59-68	27/07/24	Val d’Isere	Solaise	600	Mirage 13
69-74	28/07/24	Val d’Isere	Solaise	600	Mirage 13
75	16/12/24	Val d’Isere	Charvet		Mirage 13
76-78	28/12/24	Val d’Isere	Banane		Mirage 13
79-81		Val d’Isere	Solaise	600	Mirage 13
82	24/01/25	Val d’Isere	Banane		R3X 11
83-86		Val d’Isere	Solaise 	600	R3X 11
87-90	26/01/25	Val d'Isere	Solaise 	600	R3X 11
91-92	07/02/25 	Val d'Isere	Banane 		R3X 11
93-96		Val d'Isere	Solaise	600	R3X 11
97-98	09/02/25	Val d'Isere	Banane 		R3X 11
99-106		Val d'Isere	Solaise	600	R3X 11
107-108	15/02/25	Val d'Isere	Banane		R3X 11
109-113		Val d'Isere	Solaise	600	R3X 11
114	27/02/25	Val d'Isere	Solaise		R3X 11
115-120	10/03/25	Val d'Isere	Solaise	600	R3X 11
121-123	17/03/25	Val d'Isere	Banane		R3X 11
124		Val d'Isere	Charvet 		R3X 11
125		Val d'Isere	Manchet 		R3X 11
126-131		Val d'Isere	Solaise	600	R3X 11
132-137	25/03/25	Val d'Isere	Solaise	600	R3X 11
138-143	26/03/25	Val d'Isere	Solaise	600	R3X 11
144-156	28/03/25	Val d'Isere	Solaise	600	R3X 11
157-158	30/03/25	Val d'Isere	Solaise	600	R3X 11
159-163		Val d'Isere	Solaise	600	Flame2 10
165		Chartreuse	Saint Hilaire N	800	R3X 11
166	05/04/25	Chartreuse	Dent de Crolles	1400	R3X 11
167-168		Chartreuse	Saint Hilaire N	800	R3X 11
169		Chartreuse	Saint Hilaire N	1h	BGD Magic
170-174	07/04/25	Val d’Isere	Solaise 	600/soaring	R3X 11
175-178	08/04/25	Val d’Isere	Solaise	600	R3X 11
179-184	21/04/25	Val d’Isere	Solaise		R3X 11
185-186	01/05/25	Chartreuse 	St Hilaire E		R3X 11
187-188	01/08/25	Val d’Isere	Solaise 		R3X 11
189		Val d’Isere	Solaise		Fuze 15
190-191		Val d’Isere	Solaise		R3X 11
192-196	17/01/2026	La Clusaz	Balme 	1000	R3X 11
197-201	01/02/2026	Grand Bornand			R3X 11
202-207	08/02/2026	Grand Bo			R3X 11
208-209	05/03/2026	Samoens			R3X 11
210	20/06/2026	Col des Fretes	GoFretes	1100	R3X 11
211	08/09/2026	Col des Fretes 		1100	R3X 11
212-213	18/09/2026	Saint Hil	Coupe Icare 	700	R3X 11
214-215	19/09/2026	Saint Hil	Coupe Icare	700	R3X 11

''';

void main() {
  test('parses the real Notes speedflying logbook export', () {
    final result = ExportService().parseNotesTable(sample);

    // 73 table rows; Nº 164 has no corresponding row in the source note
    // (a genuine gap in the logbook), so 215 numbered flights become 214
    // parsed individual flights once grouped ranges are expanded.
    expect(result.length, 73);

    final totalFlights = result.fold<int>(0, (sum, f) => sum + f.count);
    expect(totalFlights, 214);

    expect(result.first.sourceNumber, '1');
    expect(result.first.date, DateTime(2023, 5, 21));
    expect(result.first.site, 'Vercors');
    expect(result.first.run, 'l’Aigle');
    expect(result.first.wing, 'Swoop 16');

    // Blank date row inherits the previous row's date. sourceNumber stores
    // just the starting number; flightNumberLabel rebuilds the full range.
    final row2 = result[1];
    expect(row2.sourceNumber, '2');
    expect(row2.flightNumberLabel, '2-3');
    expect(row2.count, 2);
    expect(row2.date, DateTime(2023, 5, 21));

    // 2-digit vs 4-digit years both resolve correctly.
    final last = result.last;
    expect(last.date, DateTime(2026, 9, 19));

    // Empty Run / Dénivelé columns.
    final row75 = result.firstWhere((f) => f.sourceNumber == '75');
    expect(row75.run, 'Charvet');
    expect(row75.verticalOrDuration, '');

    // Mixed "meters/soaring" and pure duration values.
    final row170 = result.firstWhere((f) => f.sourceNumber == '170');
    expect(row170.flightNumberLabel, '170-174');
    expect(row170.verticalOrDuration, '600/soaring');
    expect(row170.verticalMeters, 600);

    final row169 = result.firstWhere((f) => f.sourceNumber == '169');
    expect(row169.verticalOrDuration, '1h');
    expect(row169.verticalMeters, null);
  });
}
