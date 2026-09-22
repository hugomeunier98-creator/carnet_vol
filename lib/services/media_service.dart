import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:file_selector/file_selector.dart';
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
      thumbnail: processed.thumbnail,
      sourceHash: hash,
      capturedAt: processed.capturedAt,
    );
  }

  /// Saves the media, returning the id of the stored record.
  Future<String> saveForFlight(PendingMedia pending, String flightId) async {
    final id = _uuid.v4();
    await _store.add(MediaItem(
      id: id,
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
    return id;
  }

  Future<MediaItem?> getById(String id) => _store.getById(id);

  Future<List<MediaItem>> forFlight(String flightId) => _store.forFlight(flightId);

  Future<Set<String>> flightIdsWithMedia() => _store.flightIdsWithMedia();

  Future<void> delete(String id) => _store.delete(id);

  Future<void> deleteAll(Iterable<String> ids) => _store.deleteAll(ids);

  /// Repoints an already-saved media record at a different flight, without
  /// the caller needing to hold its bytes in memory.
  Future<void> reassignFlight(String mediaId, String newFlightId) =>
      _store.reassignFlight(mediaId, newFlightId);

  /// Saves a copy of the media's bytes to the device (e.g. Files/Camera Roll
  /// on iOS), using its full original quality bytes as stored.
  Future<void> download(String fileName, String mimeType, Uint8List bytes) async {
    final location = await getSaveLocation(suggestedName: fileName);
    if (location == null) return;
    final file = XFile.fromData(bytes, mimeType: mimeType, name: fileName);
    await file.saveTo(location.path);
  }

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
