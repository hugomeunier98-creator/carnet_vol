import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carnet_vol/services/photos_link.dart';

void main() {
  test('searchQuery formats the date as dd-mm-yyyy', () {
    expect(PhotosLink.searchQuery(DateTime(2026, 9, 22)), '22-09-2026');
    expect(PhotosLink.searchQuery(DateTime(2025, 3, 7)), '07-03-2025');
  });

  final date = DateTime(2026, 9, 22);
  const search = 'https://photos.google.com/search/22%20septembre%202026';

  test('iPhone opens Photos, date to paste as dd-mm-yyyy', () {
    final link = PhotosLink.forDate(date, TargetPlatform.iOS);
    expect(link.url, 'photos-redirect://');
    expect(link.query, '22-09-2026');
    expect(link.opensApp, isTrue);
  });

  test('Android opens the Google Photos app on the date search', () {
    final link = PhotosLink.forDate(date, TargetPlatform.android);
    expect(link.query, '22 septembre 2026');
    expect(
      link.url,
      startsWith(
        'intent://photos.google.com/search/22%20septembre%202026#Intent;',
      ),
    );
    expect(link.url, contains('package=com.google.android.apps.photos'));
    expect(
      link.url,
      contains('S.browser_fallback_url=${Uri.encodeComponent(search)}'),
    );
    expect(link.opensApp, isTrue);
  });

  test('computers open the Google Photos website in a new tab', () {
    final link = PhotosLink.forDate(date, TargetPlatform.windows);
    expect(link.url, search);
    expect(link.opensApp, isFalse);
  });
}
