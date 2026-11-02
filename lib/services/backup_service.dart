import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:share_plus/share_plus.dart';

import '../models/flight_entry.dart';
import '../models/run_location.dart';
import '../utils/date_format.dart';
import 'storage_service.dart';

/// Everything the app stores, in one file: flights, GPS points of sites and
/// runs, and the known site/run/wing names. On iPhone, a home-screen app
/// keeps its data apart from Safari and loses it when its icon is removed,
/// so this is what to save before reinstalling.
class Backup {
  final List<FlightEntry> flights;
  final List<RunLocation> runLocations;
  final List<String> sites;
  final List<String> runs;
  final List<String> wings;

  const Backup({
    required this.flights,
    required this.runLocations,
    required this.sites,
    required this.runs,
    required this.wings,
  });

  static const _format = 'carnet_vol_backup';

  String toJson() => const JsonEncoder.withIndent('  ').convert({
        'format': _format,
        'version': 1,
        'flights': flights.map((f) => f.toJson()).toList(),
        'runLocations': runLocations.map((l) => l.toJson()).toList(),
        'sites': sites,
        'runs': runs,
        'wings': wings,
      });

  /// Null when [content] isn't a backup made by this app.
  static Backup? tryParse(String content) {
    try {
      final json = jsonDecode(content);
      if (json is! Map<String, dynamic> || json['format'] != _format) return null;
      List<String> names(String key) =>
          (json[key] as List<dynamic>? ?? []).cast<String>();
      return Backup(
        flights: (json['flights'] as List<dynamic>)
            .map((e) => FlightEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        runLocations: (json['runLocations'] as List<dynamic>? ?? [])
            .map((e) => RunLocation.fromJson(e as Map<String, dynamic>))
            .toList(),
        sites: names('sites'),
        runs: names('runs'),
        wings: names('wings'),
      );
    } catch (_) {
      return null;
    }
  }
}

class BackupService {
  final _storage = StorageService();

  Future<Backup> load() async {
    final results = await Future.wait([
      _storage.loadFlights(),
      _storage.loadRunLocations(),
      _storage.loadSites(),
      _storage.loadRuns(),
      _storage.loadWings(),
    ]);
    return Backup(
      flights: results[0] as List<FlightEntry>,
      runLocations: results[1] as List<RunLocation>,
      sites: results[2] as List<String>,
      runs: results[3] as List<String>,
      wings: results[4] as List<String>,
    );
  }

  /// Replaces everything stored with [backup].
  Future<void> restore(Backup backup) async {
    await _storage.saveFlights(backup.flights);
    await _storage.saveRunLocations(backup.runLocations);
    await _storage.saveSites(backup.sites);
    await _storage.saveRuns(backup.runs);
    await _storage.saveWings(backup.wings);
  }

  /// Offers the backup file through the share sheet (on iPhone: "Enregistrer
  /// dans Fichiers", AirDrop, mail...), which works from a home-screen app
  /// where plain downloads don't.
  Future<void> share() async {
    final backup = await load();
    final now = DateTime.now();
    final name = 'carnet_vol_sauvegarde_${formatNumericDate(now).split('/').reversed.join('-')}.json';
    final file = XFile.fromData(
      Uint8List.fromList(utf8.encode(backup.toJson())),
      mimeType: 'application/json',
      name: name,
    );
    await SharePlus.instance.share(ShareParams(files: [file], fileNameOverrides: [name]));
  }

  /// Lets the user pick a backup file; null if cancelled. Throws
  /// [FormatException] when the file isn't a backup.
  Future<Backup?> pick() async {
    const jsonType = XTypeGroup(label: 'JSON', extensions: ['json']);
    final file = await openFile(acceptedTypeGroups: [jsonType]);
    if (file == null) return null;
    final backup = Backup.tryParse(await file.readAsString());
    if (backup == null) {
      throw const FormatException("Ce fichier n'est pas une sauvegarde du carnet de vol.");
    }
    return backup;
  }
}
