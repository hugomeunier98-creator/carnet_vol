import 'package:idb_shim/idb.dart';

import '../models/media_item.dart';
import 'idb_factory_stub.dart' if (dart.library.html) 'idb_factory_web.dart'
    as idb_platform;

class MediaStore {
  static const _dbName = 'carnet_vol_media';
  static const _dbVersion = 2;
  static const _storeName = 'media';
  static const _flightIndexName = 'flightId';
  static const _hashIndexName = 'sourceHash';

  Database? _db;

  Future<Database> _open() async {
    final existing = _db;
    if (existing != null) return existing;
    final factory = idb_platform.getIdbFactory();
    final db = await factory.open(
      _dbName,
      version: _dbVersion,
      onUpgradeNeeded: (VersionChangeEvent event) {
        final ObjectStore store;
        if (event.oldVersion < 1) {
          store = event.database.createObjectStore(_storeName, keyPath: 'id');
          store.createIndex(_flightIndexName, 'flightId');
        } else {
          store = event.transaction.objectStore(_storeName);
        }
        if (event.oldVersion < 2) {
          store.createIndex(_hashIndexName, 'sourceHash');
        }
      },
    );
    _db = db;
    return db;
  }

  /// Whether a media file with this content hash has already been imported
  /// (to any flight), so re-picking the same photo/video can be skipped.
  Future<bool> hashExists(String hash) async {
    if (hash.isEmpty) return false;
    final db = await _open();
    final txn = db.transaction(_storeName, idbModeReadOnly);
    final index = txn.objectStore(_storeName).index(_hashIndexName);
    final count = await index.count(hash);
    await txn.completed;
    return count > 0;
  }

  Future<void> add(MediaItem item) async {
    final db = await _open();
    final txn = db.transaction(_storeName, idbModeReadWrite);
    await txn.objectStore(_storeName).put(item.toMap());
    await txn.completed;
  }

  Future<MediaItem?> getById(String id) async {
    final db = await _open();
    final txn = db.transaction(_storeName, idbModeReadOnly);
    final raw = await txn.objectStore(_storeName).getObject(id);
    await txn.completed;
    if (raw is! Map) return null;
    return MediaItem.fromMap(raw);
  }

  /// Lists the media for a flight *without* their full bytes (only
  /// thumbnails), so viewing a flight with many/large videos or photos
  /// doesn't hold every file's full bytes in memory at once - just to show
  /// a grid of small tiles. Call [getById] to load one item's full bytes
  /// on demand (viewing/downloading it).
  Future<List<MediaItem>> forFlight(String flightId) async {
    final db = await _open();
    final txn = db.transaction(_storeName, idbModeReadOnly);
    final index = txn.objectStore(_storeName).index(_flightIndexName);
    final items = <MediaItem>[];
    await for (final cursor in index.openCursor(key: flightId, autoAdvance: true)) {
      final value = cursor.value;
      if (value is Map) {
        final stripped = Map<dynamic, dynamic>.from(value);
        stripped['bytes'] = null;
        items.add(MediaItem.fromMap(stripped));
      }
    }
    await txn.completed;
    items.sort((a, b) => a.addedAt.compareTo(b.addedAt));
    return items;
  }

  Future<void> delete(String id) async {
    final db = await _open();
    final txn = db.transaction(_storeName, idbModeReadWrite);
    await txn.objectStore(_storeName).delete(id);
    await txn.completed;
  }

  /// Deletes several records at once (used to clean up media that was
  /// eagerly saved during a bulk import the user then abandoned or skipped).
  Future<void> deleteAll(Iterable<String> ids) async {
    final db = await _open();
    final txn = db.transaction(_storeName, idbModeReadWrite);
    final store = txn.objectStore(_storeName);
    for (final id in ids) {
      await store.delete(id);
    }
    await txn.completed;
  }

  /// Updates only the flightId of an already-stored record, without the
  /// caller needing to hold its (potentially large) bytes in memory.
  Future<void> reassignFlight(String id, String newFlightId) async {
    final db = await _open();
    final txn = db.transaction(_storeName, idbModeReadWrite);
    final store = txn.objectStore(_storeName);
    final raw = await store.getObject(id);
    if (raw is Map) {
      final updated = Map<dynamic, dynamic>.from(raw);
      updated['flightId'] = newFlightId;
      await store.put(updated);
    }
    await txn.completed;
  }

  /// The set of flight ids that have at least one media item, without
  /// loading the (potentially large) media records themselves.
  Future<Set<String>> flightIdsWithMedia() async {
    final db = await _open();
    final txn = db.transaction(_storeName, idbModeReadOnly);
    final index = txn.objectStore(_storeName).index(_flightIndexName);
    final ids = <String>{};
    await for (final cursor in index.openKeyCursor(autoAdvance: true)) {
      ids.add(cursor.key as String);
    }
    await txn.completed;
    return ids;
  }
}
