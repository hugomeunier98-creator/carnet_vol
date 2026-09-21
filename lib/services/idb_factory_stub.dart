import 'package:idb_shim/idb_client_memory.dart';

/// Non-web fallback (also used by `flutter test`, which runs on the Dart VM
/// where IndexedDB doesn't exist): an in-memory store, good enough for tests.
IdbFactory getIdbFactory() => newIdbFactoryMemory();
