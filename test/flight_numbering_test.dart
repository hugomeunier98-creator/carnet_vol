import 'package:flutter_test/flutter_test.dart';
import 'package:carnet_vol/models/flight_entry.dart';
import 'package:carnet_vol/utils/flight_numbering.dart';

FlightEntry _flight(String id, DateTime date, {int count = 1, String? sourceNumber}) {
  return FlightEntry(
    id: id,
    date: date,
    site: 'Site',
    wing: 'Wing',
    count: count,
    sourceNumber: sourceNumber,
  );
}

void main() {
  test('numbers stay chronological even when a later flight is added first', () {
    final flights = [
      _flight('a', DateTime(2026, 1, 10)),
      _flight('b', DateTime(2026, 3, 1)),
    ];
    // Simulate adding an earlier flight after the fact (e.g. backfilling a
    // forgotten entry) - it must not just get appended as the highest number.
    flights.add(_flight('c', DateTime(2026, 2, 1)));

    final labels = computeFlightNumberLabels(flights);
    expect(labels['a'], '#1');
    expect(labels['c'], '#2');
    expect(labels['b'], '#3');
  });

  test('grouped flights consume a contiguous range', () {
    final flights = [
      _flight('a', DateTime(2026, 1, 1), count: 3),
      _flight('b', DateTime(2026, 1, 2)),
    ];
    final labels = computeFlightNumberLabels(flights);
    expect(labels['a'], '#1 - #3');
    expect(labels['b'], '#4');
  });

  test('same-day imported flights keep their original relative order', () {
    final flights = [
      _flight('late', DateTime(2026, 1, 1), sourceNumber: '5'),
      _flight('early', DateTime(2026, 1, 1), sourceNumber: '3'),
    ];
    final labels = computeFlightNumberLabels(flights);
    expect(labels['early'], '#1');
    expect(labels['late'], '#2');
  });
}
