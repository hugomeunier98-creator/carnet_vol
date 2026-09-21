import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'exif_date_reader.dart';

class ProcessedMedia {
  final Uint8List bytes;
  final DateTime? capturedAt;

  const ProcessedMedia({required this.bytes, this.capturedAt});
}

class MediaProcessor {
  static const _maxDimension = 1600;
  static const _jpegQuality = 82;

  /// Compresses/resizes an image for storage and resolves its capture date
  /// (EXIF when available, otherwise [fallbackDate]).
  ProcessedMedia processImage(Uint8List original, DateTime? fallbackDate) {
    final capturedAt = readJpegExifDate(original) ?? fallbackDate;
    try {
      final decoded = img.decodeImage(original);
      if (decoded == null) {
        return ProcessedMedia(bytes: original, capturedAt: capturedAt);
      }
      final needsResize = decoded.width > _maxDimension || decoded.height > _maxDimension;
      final resized = needsResize
          ? img.copyResize(
              decoded,
              width: decoded.width >= decoded.height ? _maxDimension : null,
              height: decoded.height > decoded.width ? _maxDimension : null,
            )
          : decoded;
      final encoded = img.encodeJpg(resized, quality: _jpegQuality);
      return ProcessedMedia(bytes: Uint8List.fromList(encoded), capturedAt: capturedAt);
    } catch (_) {
      // Unsupported/undecodable format: keep the original bytes untouched.
      return ProcessedMedia(bytes: original, capturedAt: capturedAt);
    }
  }
}
