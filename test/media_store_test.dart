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

  test('reassignFlight updates only the flightId, preserving other fields', () async {
    final store = MediaStore();
    await store.add(MediaItem(
      id: 'm1',
      flightId: '__pending_import__',
      fileName: 'clip.mp4',
      mimeType: 'video/mp4',
      isVideo: true,
      bytes: Uint8List.fromList([9, 9, 9]),
      sourceHash: 'h1',
      addedAt: DateTime(2026, 2, 1),
    ));

    await store.reassignFlight('m1', 'flight-42');

    final items = await store.forFlight('flight-42');
    expect(items, hasLength(1));
    expect(items.first.id, 'm1');
    expect(items.first.fileName, 'clip.mp4');

    final full = await store.getById('m1');
    expect(full?.bytes, [9, 9, 9]);

    expect(await store.forFlight('__pending_import__'), isEmpty);
  });

  test('forFlight omits full bytes (only thumbnails); getById loads them', () async {
    final store = MediaStore();
    await store.add(MediaItem(
      id: 'p1',
      flightId: 'flight-9',
      fileName: 'photo.jpg',
      mimeType: 'image/jpeg',
      isVideo: false,
      bytes: Uint8List.fromList(List.filled(1000, 7)),
      thumbnail: Uint8List.fromList([1, 2, 3]),
      sourceHash: 'h9',
      addedAt: DateTime(2026, 4, 1),
    ));

    final listed = await store.forFlight('flight-9');
    expect(listed.single.bytes, isEmpty);
    expect(listed.single.thumbnail, [1, 2, 3]);

    final full = await store.getById('p1');
    expect(full?.bytes, hasLength(1000));
  });

  test('getById returns null for a missing record', () async {
    final store = MediaStore();
    expect(await store.getById('does-not-exist'), null);
  });

  test('deleteAll removes multiple records at once', () async {
    final store = MediaStore();
    for (final id in ['a', 'b', 'c']) {
      await store.add(MediaItem(
        id: id,
        flightId: 'flight-x',
        fileName: '$id.jpg',
        mimeType: 'image/jpeg',
        isVideo: false,
        bytes: Uint8List.fromList([1]),
        sourceHash: 'hash-$id',
        addedAt: DateTime(2026, 3, 1),
      ));
    }

    await store.deleteAll(['a', 'c']);

    final remaining = await store.forFlight('flight-x');
    expect(remaining.map((m) => m.id), ['b']);
  });
}
