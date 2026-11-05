import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/preset_sites.dart';
import '../models/flight_entry.dart';
import '../models/run_location.dart';

class StorageService {
  static const _flightsKey = 'flights';
  static const _sitesKey = 'known_sites';
  static const _runsKey = 'known_runs';
  static const _wingsKey = 'known_wings';
  static const _runLocationsKey = 'run_locations';

  Future<List<FlightEntry>> loadFlights() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_flightsKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => FlightEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveFlights(List<FlightEntry> flights) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(flights.map((f) => f.toJson()).toList());
    await prefs.setString(_flightsKey, raw);
  }

  Future<List<String>> loadSites() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_sitesKey) ?? [];
  }

  Future<void> saveSites(List<String> sites) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_sitesKey, sites);
  }

  Future<List<String>> loadRuns() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_runsKey) ?? [];
  }

  Future<void> saveRuns(List<String> runs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_runsKey, runs);
  }

  Future<List<String>> loadWings() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_wingsKey) ?? [];
  }

  Future<void> saveWings(List<String> wings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_wingsKey, wings);
  }

  Future<List<RunLocation>> loadRunLocations() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_runLocationsKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => RunLocation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveRunLocations(List<RunLocation> locations) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(locations.map((l) => l.toJson()).toList());
    await prefs.setString(_runLocationsKey, raw);
  }

  /// Adds the app's preset sites (lib/data/preset_sites.dart), once: a
  /// preset later renamed or moved by the user doesn't come back.
  Future<void> seedPresetSites() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getInt(_presetSitesKey) == _presetSitesVersion) return;
    await saveRunLocations(withPresets(await loadRunLocations()));
    final sites = await loadSites();
    final runs = await loadRuns();
    await saveSites(
      ({...sites, for (final p in presetSites) p.site}).toList()..sort(),
    );
    await saveRuns(
      ({
        ...runs,
        for (final p in presetSites)
          if (p.run.isNotEmpty) p.run,
      }).toList()..sort(),
    );
    await prefs.setInt(_presetSitesKey, _presetSitesVersion);
  }

  static const _presetSitesKey = 'preset_sites_version';
  static const _presetSitesVersion = 1;
}
