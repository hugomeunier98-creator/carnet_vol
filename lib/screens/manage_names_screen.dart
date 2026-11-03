import 'package:flutter/material.dart';

import '../models/flight_entry.dart';
import '../models/run_location.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import '../utils/run_locations.dart';
import '../widgets/location_edit_dialog.dart';

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

  int _flightCountForSite(String site) =>
      _flights.where((f) => f.site == site).length;

  int _flightCountForRun(String run) =>
      _flights.where((f) => f.run == run).length;

  List<RunLocation> _mergeLocationsForSiteRename(
    String oldSite,
    String newSite,
  ) {
    final byKey = <String, RunLocation>{};
    for (final l in _locations) {
      final site = l.site == oldSite ? newSite : l.site;
      final key = '$site|${l.run}';
      final existing = byKey[key];
      byKey[key] = existing == null
          ? RunLocation(
              site: site,
              run: l.run,
              takeoffLat: l.takeoffLat,
              takeoffLng: l.takeoffLng,
              landingLat: l.landingLat,
              landingLng: l.landingLng,
            )
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
          ? RunLocation(
              site: l.site,
              run: run,
              takeoffLat: l.takeoffLat,
              takeoffLng: l.takeoffLng,
              landingLat: l.landingLat,
              landingLng: l.landingLng,
            )
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
            Text(
              'Actuellement : "$current"',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Autocomplete<String>(
              optionsBuilder: (v) {
                if (v.text.isEmpty) return suggestions;
                return suggestions.where(
                  (s) => s.toLowerCase().contains(v.text.toLowerCase()),
                );
              },
              initialValue: TextEditingValue(text: current),
              onSelected: (v) => controller.text = v,
              fieldViewBuilder:
                  (context, fieldController, focusNode, onSubmit) {
                    fieldController.text = controller.text;
                    fieldController.addListener(
                      () => controller.text = fieldController.text,
                    );
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
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

  /// Takeoff/landing of [site] itself (empty run), on the map or as text.
  Future<void> _editSiteLocation(String site) async {
    final result = await showDialog<RunLocation>(
      context: context,
      builder: (context) => LocationEditDialog(
        site: site,
        run: '',
        existing: _siteLocation(site),
        fallbackCenter: fallbackCenterFor(_locations, site),
      ),
    );
    if (result == null) return;
    setState(() => _locations = upsertLocation(_locations, result));
    await _persist();
  }

  RunLocation? _siteLocation(String site) {
    for (final l in _locations) {
      if (l.matches(site, '')) return l;
    }
    return null;
  }

  Future<void> _addSite() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        void submit() {
          final v = controller.text.trim();
          if (v.isNotEmpty) Navigator.pop(context, v);
        }

        return AlertDialog(
          title: const Text('Nouveau site'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nom du site'),
            onSubmitted: (_) => submit(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            FilledButton(onPressed: submit, child: const Text('Suivant')),
          ],
        );
      },
    );
    controller.dispose();
    if (name == null) return;
    if (!_sites.contains(name)) {
      setState(() => _sites = ([..._sites, name])..sort());
      await _persist();
    }
    // Then its takeoff and landing; cancelling keeps the site without them.
    await _editSiteLocation(name);
  }

  Widget _siteList() {
    if (_sites.isEmpty) {
      return const Center(
        child: Text(
          'Aucun site enregistré.\nAjoute-en un avec +.',
          textAlign: TextAlign.center,
        ),
      );
    }
    final cs = Theme.of(context).colorScheme;
    final sorted = List<String>.of(_sites)..sort();
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final name = sorted[index];
        final location = _siteLocation(name);
        final points = [
          if (location?.hasTakeoff ?? false) 'déco',
          if (location?.hasLanding ?? false) 'atterro',
        ];
        final count = _flightCountForSite(name);
        return ListTile(
          title: Text(name),
          subtitle: Text(
            '$count vol${count > 1 ? 's' : ''} · '
            '${points.isEmpty ? 'pas de GPS' : 'GPS ${points.join(' & ')}'}',
          ),
          onTap: () => _editSiteLocation(name),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  points.isEmpty
                      ? Icons.add_location_alt_outlined
                      : Icons.location_on,
                  color: points.isEmpty
                      ? cs.onSurfaceVariant
                      : AppColors.accentOn(context),
                ),
                tooltip: "Coordonnées du déco et de l'atterro",
                onPressed: () => _editSiteLocation(name),
              ),
              IconButton(
                icon: const Icon(Icons.drive_file_rename_outline),
                tooltip: 'Renommer / fusionner',
                onPressed: () => _renameSite(name),
              ),
            ],
          ),
        );
      },
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
          tabs: const [
            Tab(text: 'Sites'),
            Tab(text: 'Runs'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _siteList(),
                _nameList(
                  names: _runs,
                  countFor: _flightCountForRun,
                  onRename: _renameRun,
                  emptyLabel: 'Aucun run enregistré.',
                ),
              ],
            ),
      // Adding applies to sites; runs come from flights.
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (context, _) => _loading || _tabController.index != 0
            ? const SizedBox.shrink()
            : FloatingActionButton(
                tooltip: 'Nouveau site',
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                onPressed: _addSite,
                child: const Icon(Icons.add),
              ),
      ),
    );
  }
}
