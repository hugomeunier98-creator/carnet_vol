import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Renders a frame from the middle of a video's first second onto a canvas
/// and returns it as JPEG bytes, using only browser APIs (video + canvas),
/// so it works on Flutter web without any native/platform-specific plugin.
Future<Uint8List?> generateVideoThumbnail(Uint8List videoBytes, String mimeType) async {
  final blob = web.Blob([videoBytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  final video = web.HTMLVideoElement()
    ..src = url
    ..muted = true
    ..playsInline = true
    ..preload = 'metadata';

  final completer = Completer<Uint8List?>();
  var settled = false;

  void finish(Uint8List? result) {
    if (settled) return;
    settled = true;
    web.URL.revokeObjectURL(url);
    completer.complete(result);
  }

  video.onloadedmetadata = (() {
    final duration = video.duration;
    video.currentTime = (duration.isFinite && duration > 0.6) ? 0.3 : 0.0;
  }).toJS;

  video.onseeked = (() {
    try {
      final canvas = web.HTMLCanvasElement()
        ..width = video.videoWidth
        ..height = video.videoHeight;
      final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
      ctx.drawImage(video, 0, 0);
      final dataUrl = canvas.toDataURL('image/jpeg', 0.7.toJS);
      final base64Str = dataUrl.split(',').last;
      finish(base64Decode(base64Str));
    } catch (_) {
      finish(null);
    }
  }).toJS;

  video.onerror = (() => finish(null)).toJS;

  Timer(const Duration(seconds: 6), () => finish(null));

  return completer.future;
}
