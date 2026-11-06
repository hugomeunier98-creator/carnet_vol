import 'package:flutter/foundation.dart';

import 'device_os.dart';

/// Links from a flight to the photos/videos taken that day. Nothing is
/// stored in the app: the date is copied for the search of the phone's
/// photo app.
///
/// - iPhone: Photos is opened (Apple offers no URL that opens it at a
///   given date) and the date is pasted into its search.
/// - Other phones: each maker has its own gallery and a web app can't open
///   "the default one", so the date is only copied, for the user to paste
///   into their photo app's search.
class PhotosLink {
  /// The app to open, or null when the user opens it themselves.
  final String? url;

  const PhotosLink._(this.url);

  factory PhotosLink.forDevice([TargetPlatform? platform]) =>
      (platform ?? deviceOs()) == TargetPlatform.iOS
      ? const PhotosLink._('photos-redirect://')
      : const PhotosLink._(null);

  /// Date pasted into the photo app's search, as dd-mm-yyyy.
  static String searchQuery(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.year.toString().padLeft(4, '0')}';
}
