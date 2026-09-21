import 'package:idb_shim/idb.dart';

import '../models/media_item.dart';
import 'idb_factory_stub.dart' if (dart.library.html) 'idb_factory_web.dart'
    as idb_platform;

class MediaStore {
  static const _dbName = 'carnet_vol_media';
  static const _dbVersion = 1;
  static const _storeName = 'media';
  static const _flightIndexName = 'flightId';

  Database? _db;

  Future<Database> _open() async {
    final existing = _db;
    if (existing != null) return existing;
    final factory = idb_platform.getIdbFactory();
    final db = await factory.open(
      _dbName,
      version: _dbVersion,
      onUpgradeNeeded: (VersionChangeEvent event) {
        final store = event.database.createObjectStore(_storeName, keyPath: 'id');
        store.createIndex(_flightIndexName, 'flightId');
      },
    );
    _db = db;
    return db;
  }

  Future<void> add(MediaItem item) async {
    final db = await _open();
    final txn = db.transaction(_storeName, idbModeReadWrite);
    await txn.objectStore(_storeName).put(item.toMap());
    await txn.completed;
  }

  Future<List<MediaItem>> forFlight(String flightId) async {
    final db = await _open();
    final txn = db.transaction(_storeName, idbModeReadOnly);
    final index = txn.objectStore(_storeName).index(_flightIndexName);
    final rows = await index.getAll(flightId);
    await txn.completed;
    final items = rows
        .map((row) => MediaItem.fromMap(row as Map<dynamic, dynamic>))
        .toList();
    items.sort((a, b) => a.addedAt.compareTo(b.addedAt));
    return items;
  }

  Future<void> delete(String id) async {
    final db = await _open();
    final txn = db.transaction(_storeName, idbModeReadWrite);
    await txn.objectStore(_storeName).delete(id);
    await txn.completed;
  }
}
