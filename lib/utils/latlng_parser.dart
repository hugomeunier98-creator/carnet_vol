final _latLngPattern =
    RegExp(r'^\(?\s*(-?\d+(?:[.,]\d+)?)\s*[,;]\s*(-?\d+(?:[.,]\d+)?)\s*\)?$');

/// Parses "lat, lon" or "(lat, lon)" (accepting ';' or ',' as separator and
/// either '.' or ',' as the decimal point) into a `(lat, lon)` pair.
/// Returns null when the text is empty or doesn't match.
(double, double)? parseLatLng(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  final match = _latLngPattern.firstMatch(text);
  if (match == null) return null;
  final lat = double.tryParse(match.group(1)!.replaceFirst(',', '.'));
  final lng = double.tryParse(match.group(2)!.replaceFirst(',', '.'));
  if (lat == null || lng == null) return null;
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
  return (lat, lng);
}

String formatLatLng(double? lat, double? lng) {
  if (lat == null || lng == null) return '';
  return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
}
