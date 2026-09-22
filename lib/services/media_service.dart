import 'dart:typed_data';

import 'package:crypto/crypto.dart';
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

class MediaAlreadyImportedException implements Exception {
  const MediaAlreadyImportedException();
}

/// A processed file (compressed if it's an image, date resolved) not yet
/// attached to a flight.
class PendingMedia {
  final String fileName;
  final String mimeType;
  final bool isVideo;
  final Uint8List bytes;
  final Uint8List? thumbnail;
  final String sourceHash;
  final DateTime? capturedAt;

  const PendingMedia({
    required this.fileName,
    required this.mimeType,
    required this.isVideo,
    required this.bytes,
    this.thumbnail,
    required this.sourceHash,
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

    final hash = md5.convert(bytes).toString();
    if (await _store.hashExists(hash)) {
      throw const MediaAlreadyImportedException();
    }

    if (isVideo) {
      // The thumbnail isn't generated here: decoding a video frame is slow
      // enough to noticeably stall a multi-file import. It's generated lazily
      // instead, the first time the flight's media section is opened (see
      // [backfillThumbnail]).
      final capturedAt = await file.lastModified();
      return PendingMedia(
        fileName: file.name,
        mimeType: mimeType,
        isVideo: true,
        bytes: bytes,
        sourceHash: hash,
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
      sourceHash: hash,
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
      sourceHash: pending.sourceHash,
      capturedAt: pending.capturedAt,
      addedAt: DateTime.now(),
    ));
  }

  Future<List<MediaItem>> forFlight(String flightId) => _store.forFlight(flightId);

  Future<Set<String>> flightIdsWithMedia() => _store.flightIdsWithMedia();

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
      sourceHash: item.sourceHash,
      capturedAt: item.capturedAt,
      addedAt: item.addedAt,
    ));
    return true;
  }
}
