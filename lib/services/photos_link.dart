/// Links from a flight to the photos/videos taken that day in the iPhone's
/// Photos library (iCloud included). Nothing is stored in the app: Apple
/// offers no URL that opens Photos at a given date, so we either run an
/// iOS Shortcut that filters the library by date, or copy a date that the
/// Photos search understands and open Photos.
class PhotosLink {
  /// Name of the iOS Shortcut the user installs once. Kept accent-free so
  /// it survives being typed by hand and URL-encoded.
  static const shortcutName = 'Photos du vol';

  static const photosAppUrl = 'photos-redirect://';

  static const _months = [
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
  ];

  /// Date passed to the Shortcut, as yyyy-mm-dd (parsed by "Get Dates from
  /// Input" regardless of the phone's locale).
  static String isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// Date as typed into the Photos search on a French iPhone,
  /// e.g. "22 septembre 2026".
  static String searchQuery(DateTime date) =>
      '${date.day} ${_months[date.month - 1]} ${date.year}';

  static String shortcutUrl(DateTime date) => Uri(
        scheme: 'shortcuts',
        host: 'run-shortcut',
        queryParameters: {
          'name': shortcutName,
          'input': 'text',
          'text': isoDate(date),
        },
      ).toString();
}
