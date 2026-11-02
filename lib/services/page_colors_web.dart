import 'dart:js_interop';
import 'dart:ui';

// Defined in web/index.html.
@JS('carnetVolSetPageColors')
external void _setPageColors(String top, String bottom);

String _css(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// Paints the web page behind the app: [top] shows in the iPhone status
/// bar area, [bottom] around the home indicator.
void setPageColors(Color top, Color bottom) {
  try {
    _setPageColors(_css(top), _css(bottom));
  } catch (_) {
    // Older index.html without the function: nothing to paint.
  }
}
