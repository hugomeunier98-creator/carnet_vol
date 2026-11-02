import 'dart:convert';

import '../models/flight_entry.dart';
import '../models/run_location.dart';
import '../utils/date_format.dart';
import 'storage_service.dart';

/// Everything the app stores, in one file: flights, GPS points of sites and
/// runs, and the known site/run/wing names. This is what "Exporter en JSON"
/// writes and what "Importer un fichier" reads back. On iPhone, a
/// home-screen app keeps its data apart from Safari and loses it when its
/// icon is removed, so it's also the way to carry data over a reinstall.
class Backup {
  final List<FlightEntry> flights;
  final List<RunLocation> runLocations;
  final List<String> sites;
  final List<String> runs;
  final List<String> wings;

  const Backup({
    required this.flights,
    this.runLocations = const [],
    this.sites = const [],
    this.runs = const [],
    this.wings = const [],
  });

  static const _format = 'carnet_vol_backup';

  /// e.g. "carnet_vol_2026-11-02.json"
  static String fileName(DateTime now) =>
      'carnet_vol_${formatNumericDate(now).split('/').reversed.join('-')}.json';

  String toJson() => const JsonEncoder.withIndent('  ').convert({
        'format': _format,
        'version': 1,
        'flights': flights.map((f) => f.toJson()).toList(),
        'runLocations': runLocations.map((l) => l.toJson()).toList(),
        'sites': sites,
        'runs': runs,
        'wings': wings,
      });

  /// Null when [content] isn't a file written by [toJson] (e.g. an older
  /// export holding just a list of flights).
  static Backup? tryParse(String content) {
    final Object? json;
    try {
      json = jsonDecode(content);
    } on FormatException {
      return null;
    }
    if (json is! Map<String, dynamic> || json['format'] != _format) return null;
    final map = json;
    List<String> names(String key) => (map[key] as List<dynamic>? ?? []).cast<String>();
    return Backup(
      flights: (map['flights'] as List<dynamic>)
          .map((e) => FlightEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      runLocations: (map['runLocations'] as List<dynamic>? ?? [])
          .map((e) => RunLocation.fromJson(e as Map<String, dynamic>))
          .toList(),
      sites: names('sites'),
      runs: names('runs'),
      wings: names('wings'),
    );
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

  /// Adds imported GPS points; a point for a site/run already located
  /// replaces it.
  Future<void> mergeRunLocations(List<RunLocation> imported) async {
    if (imported.isEmpty) return;
    final all = await _storage.loadRunLocations();
    for (final location in imported) {
      final idx = all.indexWhere((l) => l.matches(location.site, location.run));
      if (idx >= 0) {
        all[idx] = location;
      } else {
        all.add(location);
      }
    }
    await _storage.saveRunLocations(all);
  }
}
