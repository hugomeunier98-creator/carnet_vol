import 'package:carnet_vol/models/flight_entry.dart';
import 'package:carnet_vol/utils/flight_stats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('durations are read from the usual spellings', () {
    expect(flightMinutes('1h30'), 90);
    expect(flightMinutes('1h'), 60);
    expect(flightMinutes('2h'), 120);
    expect(flightMinutes('1.5h'), 90);
    expect(flightMinutes('1h20'), 80);
    expect(flightMinutes('45min'), 45);
    expect(flightMinutes('10m'), 10);
    expect(flightMinutes('Soaring 1h30'), 90);
    expect(flightMinutes('soaring 1h'), 60);
  });

  test('no duration, plouf or other text count as 10 min', () {
    expect(flightMinutes(''), 10);
    expect(flightMinutes('plouf'), 10);
    expect(flightMinutes('Plouf'), 10);
    expect(flightMinutes('soaring'), 10);
    expect(flightMinutes('600'), 10);
  });

  test('an entry counts its identical flights', () {
    final f = FlightEntry(
      id: 'a',
      date: DateTime(2026),
      site: 'Planfait',
      wing: 'Xi',
      verticalOrDuration: 'plouf',
      count: 2,
    );
    expect(entryMinutes(f), 20);
  });

  test('totals are grouped and sorted, largest first', () {
    FlightEntry f(String wing, String d) => FlightEntry(
      id: wing + d,
      date: DateTime(2026),
      site: 'S',
      wing: wing,
      verticalOrDuration: d,
    );
    expect(
      totalsBy(
        [f('Xi', '1h'), f('Eona', '2h'), f('Xi', '30min')],
        (e) => e.wing,
        entryMinutes,
      ),
      [('Eona', 120), ('Xi', 90)],
    );
  });

  test('minutes are written as hours', () {
    expect(formatMinutes(45), '45 min');
    expect(formatMinutes(60), '1 h');
    expect(formatMinutes(754), '12 h 34');
  });
}
