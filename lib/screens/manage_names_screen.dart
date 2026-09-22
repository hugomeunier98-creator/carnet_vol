import 'package:flutter/material.dart';

import '../models/flight_entry.dart';
import '../models/run_location.dart';
import '../services/storage_service.dart';

class ManageNamesScreen extends StatefulWidget {
  const ManageNamesScreen({super.key});

  @override
  State<ManageNamesScreen> createState() => _ManageNamesScreenState();
}

class _ManageNamesScreenState extends State<ManageNamesScreen>
    with SingleTickerProviderStateMixin {
  final _storage = StorageService();
  late final TabController _tabController;

  List<FlightEntry> _flights = [];
  List<String> _sites = [];
  List<String> _runs = [];
  List<RunLocation> _locations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final flights = await _storage.loadFlights();
    final sites = await _storage.loadSites();
    final runs = await _storage.loadRuns();
    final locations = await _storage.loadRunLocations();
    if (!mounted) return;
    setState(() {
      _flights = flights;
      _sites = sites;
      _runs = runs;
      _locations = locations;
      _loading = false;
    });
  }

  Future<void> _persist() async {
    await _storage.saveFlights(_flights);
    await _storage.saveSites(_sites);
    await _storage.saveRuns(_runs);
    await _storage.saveRunLocations(_locations);
  }

  int _flightCountForSite(String site) => _flights.where((f) => f.site == site).length;

  int _flightCountForRun(String run) => _flights.where((f) => f.run == run).length;

  List<RunLocation> _mergeLocationsForSiteRename(String oldSite, String newSite) {
    final byKey = <String, RunLocation>{};
    for (final l in _locations) {
      final site = l.site == oldSite ? newSite : l.site;
      final key = '$site|${l.run}';
      final existing = byKey[key];
      byKey[key] = existing == null
          ? RunLocation(site: site, run: l.run, takeoffLat: l.takeoffLat, takeoffLng: l.takeoffLng, landingLat: l.landingLat, landingLng: l.landingLng)
          : RunLocation(
              site: site,
              run: l.run,
              takeoffLat: existing.takeoffLat ?? l.takeoffLat,
              takeoffLng: existing.takeoffLng ?? l.takeoffLng,
              landingLat: existing.landingLat ?? l.landingLat,
              landingLng: existing.landingLng ?? l.landingLng,
            );
    }
    return byKey.values.toList();
  }

  List<RunLocation> _mergeLocationsForRunRename(String oldRun, String newRun) {
    final byKey = <String, RunLocation>{};
    for (final l in _locations) {
      final run = l.run == oldRun ? newRun : l.run;
      final key = '${l.site}|$run';
      final existing = byKey[key];
      byKey[key] = existing == null
          ? RunLocation(site: l.site, run: run, takeoffLat: l.takeoffLat, takeoffLng: l.takeoffLng, landingLat: l.landingLat, landingLng: l.landingLng)
          : RunLocation(
              site: l.site,
              run: run,
              takeoffLat: existing.takeoffLat ?? l.takeoffLat,
              takeoffLng: existing.takeoffLng ?? l.takeoffLng,
              landingLat: existing.landingLat ?? l.landingLat,
              landingLng: existing.landingLng ?? l.landingLng,
            );
    }
    return byKey.values.toList();
  }

  Future<void> _renameSite(String oldName) async {
    final newName = await _promptNewName(
      title: 'Renommer / fusionner le site',
      current: oldName,
      suggestions: _sites.where((s) => s != oldName).toList(),
    );
    if (newName == null) return;
    setState(() {
      _flights = _flights
          .map((f) => f.site == oldName ? f.copyWith(site: newName) : f)
          .toList();
      _locations = _mergeLocationsForSiteRename(oldName, newName);
      _sites = ({..._sites, newName}..remove(oldName)).toList()..sort();
    });
    await _persist();
  }

  Future<void> _renameRun(String oldName) async {
    final newName = await _promptNewName(
      title: 'Renommer / fusionner le run',
      current: oldName,
      suggestions: _runs.where((r) => r != oldName).toList(),
    );
    if (newName == null) return;
    setState(() {
      _flights = _flights
          .map((f) => f.run == oldName ? f.copyWith(run: newName) : f)
          .toList();
      _locations = _mergeLocationsForRunRename(oldName, newName);
      _runs = ({..._runs, newName}..remove(oldName)).toList()..sort();
    });
    await _persist();
  }

  Future<String?> _promptNewName({
    required String title,
    required String current,
    required List<String> suggestions,
  }) async {
    final controller = TextEditingController(text: current);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Actuellement : "$current"', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            Autocomplete<String>(
              optionsBuilder: (v) {
                if (v.text.isEmpty) return suggestions;
                return suggestions.where(
                    (s) => s.toLowerCase().contains(v.text.toLowerCase()));
              },
              initialValue: TextEditingValue(text: current),
              onSelected: (v) => controller.text = v,
              fieldViewBuilder: (context, fieldController, focusNode, onSubmit) {
                fieldController.text = controller.text;
                fieldController.addListener(() => controller.text = fieldController.text);
                return TextField(
                  controller: fieldController,
                  focusNode: focusNode,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Nouveau nom',
                    helperText: 'Choisis un nom existant pour fusionner, ou tape un nouveau nom',
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              final v = controller.text.trim();
              if (v.isEmpty || v == current) {
                Navigator.pop(context);
              } else {
                Navigator.pop(context, v);
              }
            },
            child: const Text('Renommer'),
          ),
        ],
      ),
    );
  }

  Widget _nameList({
    required List<String> names,
    required int Function(String) countFor,
    required ValueChanged<String> onRename,
    required String emptyLabel,
  }) {
    if (names.isEmpty) return Center(child: Text(emptyLabel));
    final sorted = List<String>.of(names)..sort();
    return ListView.builder(
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final name = sorted[index];
        return ListTile(
          title: Text(name),
          subtitle: Text('${countFor(name)} vol(s)'),
          trailing: IconButton(
            icon: const Icon(Icons.drive_file_rename_outline),
            tooltip: 'Renommer / fusionner',
            onPressed: () => onRename(name),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sites & runs'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Sites'), Tab(text: 'Runs')],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _nameList(
                  names: _sites,
                  countFor: _flightCountForSite,
                  onRename: _renameSite,
                  emptyLabel: 'Aucun site enregistré.',
                ),
                _nameList(
                  names: _runs,
                  countFor: _flightCountForRun,
                  onRename: _renameRun,
                  emptyLabel: 'Aucun run enregistré.',
                ),
              ],
            ),
    );
  }
}
