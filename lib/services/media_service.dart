import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../models/media_item.dart';
import 'media_processor.dart';
import 'media_store.dart';
import 'mime_utils.dart';
import 'video_thumbnail.dart';

class MediaTooLargeException implements Exception {
  final int bytes;
  const MediaTooLargeException(this.bytes);
}

/// A processed file (compressed if it's an image, date resolved) not yet
/// attached to a flight.
class PendingMedia {
  final String fileName;
  final String mimeType;
  final bool isVideo;
  final Uint8List bytes;
  final Uint8List? thumbnail;
  final DateTime? capturedAt;

  const PendingMedia({
    required this.fileName,
    required this.mimeType,
    required this.isVideo,
    required this.bytes,
    this.thumbnail,
    this.capturedAt,
  });
}

class MediaService {
  static const _maxVideoBytes = 300 * 1024 * 1024;

  final ImagePicker _picker = ImagePicker();
  final MediaProcessor _processor = MediaProcessor();
  final MediaStore _store = MediaStore();
  final Uuid _uuid = const Uuid();

  Future<List<XFile>> pickFiles() => _picker.pickMultipleMedia();

  Future<PendingMedia> process(XFile file) async {
    final bytes = await file.readAsBytes();
    final mimeType = file.mimeType ?? guessMimeType(file.name);
    final isVideo = mimeIsVideo(mimeType);

    if (isVideo && bytes.length > _maxVideoBytes) {
      throw MediaTooLargeException(bytes.length);
    }

    if (isVideo) {
      final capturedAt = await file.lastModified();
      Uint8List? thumbnail;
      try {
        thumbnail = await generateVideoThumbnail(bytes, mimeType);
      } catch (_) {
        thumbnail = null;
      }
      return PendingMedia(
        fileName: file.name,
        mimeType: mimeType,
        isVideo: true,
        bytes: bytes,
        thumbnail: thumbnail,
        capturedAt: capturedAt,
      );
    }

    final fallbackDate = await file.lastModified();
    final processed = _processor.processImage(bytes, fallbackDate);
    return PendingMedia(
      fileName: file.name,
      mimeType: 'image/jpeg',
      isVideo: false,
      bytes: processed.bytes,
      capturedAt: processed.capturedAt,
    );
  }

  Future<void> saveForFlight(PendingMedia pending, String flightId) {
    return _store.add(MediaItem(
      id: _uuid.v4(),
      flightId: flightId,
      fileName: pending.fileName,
      mimeType: pending.mimeType,
      isVideo: pending.isVideo,
      bytes: pending.bytes,
      thumbnail: pending.thumbnail,
      capturedAt: pending.capturedAt,
      addedAt: DateTime.now(),
    ));
  }

  Future<List<MediaItem>> forFlight(String flightId) => _store.forFlight(flightId);

  Future<void> delete(String id) => _store.delete(id);

  /// Generates a thumbnail for a video that doesn't have one yet (e.g. one
  /// imported before thumbnail generation existed) and persists it in place.
  Future<bool> backfillThumbnail(MediaItem item) async {
    if (!item.isVideo || item.thumbnail != null) return false;
    Uint8List? thumbnail;
    try {
      thumbnail = await generateVideoThumbnail(item.bytes, item.mimeType);
    } catch (_) {
      thumbnail = null;
    }
    if (thumbnail == null) return false;
    await _store.add(MediaItem(
      id: item.id,
      flightId: item.flightId,
      fileName: item.fileName,
      mimeType: item.mimeType,
      isVideo: item.isVideo,
      bytes: item.bytes,
      thumbnail: thumbnail,
      capturedAt: item.capturedAt,
      addedAt: item.addedAt,
    ));
    return true;
  }
}
