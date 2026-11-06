import 'package:flutter/foundation.dart';

import '../utils/date_format.dart';
import 'device_os.dart';

/// Links from a flight to the photos/videos taken that day. Nothing is
/// stored in the app: the date is copied for the search of the phone's
/// photo app, which is then opened.
///
/// - iPhone: Apple offers no URL that opens Photos at a given date, so
///   Photos is opened and the date (dd-mm-yyyy) is pasted into its search.
/// - Android and computers: Google Photos, whose search URL takes the date
///   ("22 septembre 2026") directly. On Android an intent opens the Google
///   Photos app, or the website when the app is missing.
class PhotosLink {
  final String query;
  final String url;

  /// Whether [url] leaves the app for another app (same tab) or opens a
  /// website (new tab, so the logbook stays open).
  final bool opensApp;

  /// Name of the photo app, for the button and messages.
  final String appName;

  const PhotosLink._(this.query, this.url, this.opensApp, this.appName);

  factory PhotosLink.forDate(DateTime date, [TargetPlatform? platform]) {
    switch (platform ?? deviceOs()) {
      case TargetPlatform.iOS:
        return PhotosLink._(
          searchQuery(date),
          'photos-redirect://',
          true,
          'Photos',
        );
      case TargetPlatform.android:
        final query = formatDayMonthYear(date);
        final web = googlePhotosSearchUrl(query);
        return PhotosLink._(
          query,
          'intent://photos.google.com/search/${Uri.encodeComponent(query)}'
              '#Intent;scheme=https;package=com.google.android.apps.photos;'
              'S.browser_fallback_url=${Uri.encodeComponent(web)};end',
          true,
          'Google Photos',
        );
      default:
        final query = formatDayMonthYear(date);
        return PhotosLink._(
          query,
          googlePhotosSearchUrl(query),
          false,
          'Google Photos',
        );
    }
  }

  static String googlePhotosSearchUrl(String query) =>
      'https://photos.google.com/search/${Uri.encodeComponent(query)}';

  /// Date pasted into the iPhone Photos search, as dd-mm-yyyy.
  static String searchQuery(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.year.toString().padLeft(4, '0')}';
}
