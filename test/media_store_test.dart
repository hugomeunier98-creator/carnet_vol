import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:carnet_vol/models/media_item.dart';
import 'package:carnet_vol/services/media_store.dart';

void main() {
  test('hashExists detects an already-imported file by content hash', () async {
    final store = MediaStore();
    const hash = 'abc123';

    expect(await store.hashExists(hash), false);

    await store.add(MediaItem(
      id: '1',
      flightId: 'flight-1',
      fileName: 'photo.jpg',
      mimeType: 'image/jpeg',
      isVideo: false,
      bytes: Uint8List.fromList([1, 2, 3]),
      sourceHash: hash,
      addedAt: DateTime(2026, 1, 1),
    ));

    expect(await store.hashExists(hash), true);
    expect(await store.hashExists('other-hash'), false);
  });

  test('hashExists returns false for an empty hash', () async {
    final store = MediaStore();
    expect(await store.hashExists(''), false);
  });
}
