import 'package:idb_shim/idb_browser.dart';

/// Real browser IndexedDB, persisted on the device.
IdbFactory getIdbFactory() => idbFactoryBrowser;
