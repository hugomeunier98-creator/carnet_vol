import 'package:flutter_test/flutter_test.dart';
import 'package:carnet_vol/services/photos_link.dart';

void main() {
  test('isoDate pads month and day', () {
    expect(PhotosLink.isoDate(DateTime(2026, 3, 7)), '2026-03-07');
  });

  test('searchQuery uses French month names', () {
    expect(PhotosLink.searchQuery(DateTime(2026, 9, 22)), '22 septembre 2026');
    expect(PhotosLink.searchQuery(DateTime(2025, 8, 1)), '1 août 2025');
  });

  test('shortcutUrl runs the shortcut with the flight date as text input', () {
    final uri = Uri.parse(PhotosLink.shortcutUrl(DateTime(2026, 9, 22)));
    expect(uri.scheme, 'shortcuts');
    expect(uri.host, 'run-shortcut');
    expect(uri.queryParameters, {
      'name': 'Photos du vol',
      'input': 'text',
      'text': '2026-09-22',
    });
  });
}
