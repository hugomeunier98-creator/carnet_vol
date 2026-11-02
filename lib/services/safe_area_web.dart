import 'dart:js_interop';

// Defined in web/index.html.
@JS('carnetVolSafeAreaInsets')
external JSArray<JSNumber>? _safeAreaInsets();

/// iPhone status bar / home indicator heights (top, bottom) in logical
/// pixels, which Flutter web doesn't report itself.
(double, double) safeAreaInsets() {
  try {
    final insets = _safeAreaInsets()?.toDart;
    if (insets == null || insets.length < 2) return (0, 0);
    return (insets[0].toDartDouble, insets[1].toDartDouble);
  } catch (_) {
    return (0, 0);
  }
}
