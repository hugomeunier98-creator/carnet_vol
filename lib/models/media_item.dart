import 'dart:typed_data';

class MediaItem {
  final String id;
  final String flightId;
  final String fileName;
  final String mimeType;
  final bool isVideo;
  final Uint8List bytes;
  final Uint8List? thumbnail;
  final String sourceHash;
  final DateTime? capturedAt;
  final DateTime addedAt;

  const MediaItem({
    required this.id,
    required this.flightId,
    required this.fileName,
    required this.mimeType,
    required this.isVideo,
    required this.bytes,
    this.thumbnail,
    this.sourceHash = '',
    this.capturedAt,
    required this.addedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'flightId': flightId,
        'fileName': fileName,
        'mimeType': mimeType,
        'isVideo': isVideo,
        'bytes': bytes,
        'thumbnail': thumbnail,
        'sourceHash': sourceHash,
        'capturedAt': capturedAt?.toIso8601String(),
        'addedAt': addedAt.toIso8601String(),
      };

  factory MediaItem.fromMap(Map<dynamic, dynamic> map) => MediaItem(
        id: map['id'] as String,
        flightId: map['flightId'] as String,
        fileName: map['fileName'] as String,
        mimeType: map['mimeType'] as String,
        isVideo: map['isVideo'] as bool,
        bytes: _asBytes(map['bytes']),
        thumbnail: map['thumbnail'] == null ? null : _asBytes(map['thumbnail']),
        sourceHash: (map['sourceHash'] as String?) ?? '',
        capturedAt: map['capturedAt'] != null
            ? DateTime.parse(map['capturedAt'] as String)
            : null,
        addedAt: DateTime.parse(map['addedAt'] as String),
      );

  static Uint8List _asBytes(Object? value) {
    if (value is Uint8List) return value;
    if (value is List) return Uint8List.fromList(List<int>.from(value));
    return Uint8List(0);
  }
}
