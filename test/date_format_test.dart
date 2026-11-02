import 'package:flutter_test/flutter_test.dart';
import 'package:carnet_vol/utils/date_format.dart';

void main() {
  final d = DateTime(2026, 9, 22); // a Tuesday

  test('month, long and numeric labels', () {
    expect(formatMonthYear(d), 'Septembre 2026');
    expect(formatShortMonth(d), 'sept.');
    expect(formatLongDate(d), 'Mardi 22 septembre 2026');
    expect(formatNumericDate(DateTime(2025, 3, 7)), '07/03/2025');
  });

  test('time since the last flight', () {
    expect(formatSince(d, DateTime(2026, 9, 22, 18)), "aujourd'hui");
    expect(formatSince(d, DateTime(2026, 9, 23, 1)), 'hier');
    expect(formatSince(d, DateTime(2026, 9, 27)), 'il y a 5 j');
    expect(formatSince(d, DateTime(2026, 12, 22)), 'il y a 3 mois');
    expect(formatSince(d, DateTime(2028, 10, 1)), 'il y a 2 ans');
  });
}
