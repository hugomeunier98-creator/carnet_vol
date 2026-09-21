import 'package:flutter_test/flutter_test.dart';
import 'package:carnet_vol/utils/latlng_parser.dart';

void main() {
  test('parses plain "lat, lon"', () {
    expect(parseLatLng('45.4489, 6.9622'), (45.4489, 6.9622));
  });

  test('parses without space', () {
    expect(parseLatLng('45.4489,6.9622'), (45.4489, 6.9622));
  });

  test('parses parenthesised form', () {
    expect(parseLatLng('(45.4489, 6.9622)'), (45.4489, 6.9622));
  });

  test('parses negative longitude', () {
    expect(parseLatLng('45.4489, -6.9622'), (45.4489, -6.9622));
  });

  test('parses comma as decimal separator', () {
    expect(parseLatLng('45,4489, 6,9622'), (45.4489, 6.9622));
  });

  test('returns null for empty input', () {
    expect(parseLatLng(''), null);
    expect(parseLatLng('   '), null);
  });

  test('returns null for garbage input', () {
    expect(parseLatLng('not a coordinate'), null);
  });

  test('returns null for out-of-range values', () {
    expect(parseLatLng('200, 6.9622'), null);
  });
}
