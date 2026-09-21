import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

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
}
