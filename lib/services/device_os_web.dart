import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// The phone's system, read from the browser: iOS (iPads report a Mac with
/// a touch screen), Android, else Flutter's own guess.
TargetPlatform deviceOs() {
  final ua = web.window.navigator.userAgent;
  if (RegExp('iPhone|iPad|iPod').hasMatch(ua) ||
      (ua.contains('Macintosh') && web.window.navigator.maxTouchPoints > 1)) {
    return TargetPlatform.iOS;
  }
  if (ua.contains('Android')) return TargetPlatform.android;
  return defaultTargetPlatform;
}
