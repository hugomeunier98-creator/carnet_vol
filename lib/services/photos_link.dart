/// Links from a flight to the photos/videos taken that day in the iPhone's
/// Photos library (iCloud included). Nothing is stored in the app: Apple
/// offers no URL that opens Photos at a given date, so we copy the date for
/// the Photos search and open Photos.
class PhotosLink {
  static const photosAppUrl = 'photos-redirect://';

  /// Date pasted into the Photos search, as dd-mm-yyyy.
  static String searchQuery(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.year.toString().padLeft(4, '0')}';
}
