import 'package:flutter/material.dart';

import '../models/flight_entry.dart';
import '../models/run_location.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import '../utils/run_locations.dart';
import '../utils/site_share.dart';
import '../widgets/choice_sheet.dart';
import '../widgets/clear_button.dart';
import '../widgets/location_edit_dialog.dart';
import '../widgets/share_site_sheet.dart';

/// Sites, each with its runs below it. A site is the takeoff or flying
/// area; a run is a speedflying line on that site, with its own takeoff
/// and landing. Runs come from speedflying flights and from GPS points.
class ManageNamesScreen extends StatefulWidget {
  const ManageNamesScreen({super.key});

  @override
  State<ManageNamesScreen> createState() => _ManageNamesScreenState();
}

class _ManageNamesScreenState extends State<ManageNamesScreen> {
  final _storage = StorageService();
  final _search = TextEditingController();

  List<FlightEntry> _flights = [];
  List<String> _sites = [];
  List<RunLocation> _locations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final flights = await _storage.loadFlights();
    final sites = await _storage.loadSites();
    final locations = await _storage.loadRunLocations();
    if (!mounted) return;
    setState(() {
      _flights = flights;
      _locations = locations;
      // Every site in use, even one missing from the stored names.
      _sites = {
        ...sites,
        for (final f in flights)
          if (f.site.isNotEmpty) f.site,
        for (final l in locations) l.site,
      }.toList()..sort(_compareNames);
      _loading = false;
    });
  }

  Future<void> _persist() async {
    await _storage.saveFlights(_flights);
    await _storage.saveSites(_sites);
    await _storage.saveRunLocations(_locations);
    await _storage.saveRuns(
      {
        for (final f in _flights)
          if (f.run.isNotEmpty) f.run,
        for (final l in _locations)
          if (l.run.isNotEmpty) l.run,
      }.toList()..sort(_compareNames),
    );
  }

  static int _compareNames(String a, String b) =>
      a.toLowerCase().compareTo(b.toLowerCase());

  List<String> _runsOf(String site) => {
    for (final f in _flights)
      if (f.site == site && f.run.isNotEmpty) f.run,
    for (final l in _locations)
      if (l.site == site && l.run.isNotEmpty) l.run,
  }.toList()..sort(_compareNames);

  /// Number of flights (an entry can group several) on [site], or on one
  /// of its runs.
  int _flightCount(String site, [String? run]) => _flights
      .where((f) => f.site == site && (run == null || f.run == run))
      .fold(0, (sum, f) => sum + f.count);

  RunLocation? _locationOf(String site, String run) {
    for (final l in _locations) {
      if (l.matches(site, run)) return l;
    }
    return null;
  }

  /// Moves the points [to] gives a new (site, run) for. Where two end up on
  /// the same site and run, the one already there wins, point by point.
  List<RunLocation> _relocate((String, String)? Function(RunLocation) to) {
    final byKey = <String, RunLocation>{};
    void put(RunLocation l) {
      final key = '${l.site}|${l.run}';
      final e = byKey[key];
      byKey[key] = e == null
          ? l
          : RunLocation(
              site: l.site,
              run: l.run,
              takeoffLat: e.takeoffLat ?? l.takeoffLat,
              takeoffLng: e.takeoffLng ?? l.takeoffLng,
              landingLat: e.landingLat ?? l.landingLat,
              landingLng: e.landingLng ?? l.landingLng,
            );
    }

    for (final l in _locations) {
      if (to(l) == null) put(l);
    }
    for (final l in _locations) {
      final dest = to(l);
      if (dest == null) continue;
      put(
        RunLocation(
          site: dest.$1,
          run: dest.$2,
          takeoffLat: l.takeoffLat,
          takeoffLng: l.takeoffLng,
          landingLat: l.landingLat,
          landingLng: l.landingLng,
        ),
      );
    }
    return byKey.values.toList();
  }

  // --- Sites ---

  Future<void> _addSite() async {
    final name = await _promptName(title: 'Nouveau site', label: 'Nom du site');
    if (name == null) return;
    if (!_sites.contains(name)) {
      setState(() => _sites = [..._sites, name]..sort(_compareNames));
      await _persist();
    }
    // Then its takeoff and landing; cancelling keeps the site without them.
    await _editLocation(name, '');
  }

  Future<void> _renameSite(String oldName) async {
    final newName = await _promptName(
      title: 'Renommer / fusionner le site',
      label: 'Nouveau nom',
      current: oldName,
      suggestions: _sites.where((s) => s != oldName).toList(),
      helper: 'Choisis un site existant pour fusionner',
    );
    if (newName == null || newName == oldName) return;
    setState(() {
      _flights = [
        for (final f in _flights)
          f.site == oldName ? f.copyWith(site: newName) : f,
      ];
      _locations = _relocate(
        (l) => l.site == oldName ? (newName, l.run) : null,
      );
      _sites = ({..._sites, newName}..remove(oldName)).toList()
        ..sort(_compareNames);
    });
    await _persist();
  }

  Future<void> _deleteSite(String site) async {
    final count = _flightCount(site);
    final others = _sites.where((s) => s != site).toList();
    String? target;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Supprimer « $site » ?'),
          content: count == 0
              ? const Text(
                  'Aucun vol sur ce site. Ses points GPS et ses runs '
                  'seront supprimés.',
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '$count vol${count > 1 ? 's' : ''} sur ce site. '
                      'Déplace-les vers :',
                    ),
                    const SizedBox(height: 12),
                    ChoiceFilterField(
                      label: 'Site',
                      value: target,
                      options: others,
                      allLabel: 'Choisir un site',
                      onChanged: (v) => setDialogState(() => target = v),
                    ),
                  ],
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: count > 0 && target == null
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('Supprimer'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    setState(() {
      if (target != null) {
        _flights = [
          for (final f in _flights)
            f.site == site ? f.copyWith(site: target) : f,
        ];
      }
      _locations = _locations.where((l) => l.site != site).toList();
      _sites = _sites.where((s) => s != site).toList();
    });
    await _persist();
  }

  // --- Runs ---

  Future<void> _addRun(String site) async {
    final name = await _promptName(
      title: 'Nouveau run · $site',
      label: 'Nom du run',
    );
    if (name == null) return;
    if (_locationOf(site, name) == null) {
      // Kept as an empty point until its takeoff and landing are set.
      setState(
        () => _locations = [..._locations, RunLocation(site: site, run: name)],
      );
      await _persist();
    }
    await _editLocation(site, name);
  }

  Future<void> _renameRun(String site, String oldName) async {
    final newName = await _promptName(
      title: 'Renommer / fusionner le run',
      label: 'Nouveau nom',
      current: oldName,
      suggestions: _runsOf(site).where((r) => r != oldName).toList(),
      helper: 'Choisis un run de $site pour fusionner',
    );
    if (newName == null || newName == oldName) return;
    setState(() {
      _flights = [
        for (final f in _flights)
          f.site == site && f.run == oldName ? f.copyWith(run: newName) : f,
      ];
      _locations = _relocate(
        (l) => l.matches(site, oldName) ? (site, newName) : null,
      );
    });
    await _persist();
  }

  Future<void> _deleteRun(String site, String run) async {
    final count = _flightCount(site, run);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Supprimer le run « $run » ?'),
        content: Text(
          count == 0
              ? 'Ses points GPS seront supprimés.'
              : 'Ses $count vol${count > 1 ? 's' : ''} restent sur $site, '
                    'sans run. Ses points GPS seront supprimés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _flights = [
        for (final f in _flights)
          f.site == site && f.run == run ? f.copyWith(run: '') : f,
      ];
      _locations = _locations.where((l) => !l.matches(site, run)).toList();
    });
    await _persist();
  }

  // --- Shared ---

  void _share(String site, String run) => showShareSiteSheet(
    context,
    siteShareText(site, run, _locationOf(site, run)),
  );

  /// Takeoff and landing of [site] itself (empty [run]) or of one of its
  /// runs, on the map or as text.
  Future<void> _editLocation(String site, String run) async {
    final result = await showDialog<RunLocation>(
      context: context,
      builder: (context) => LocationEditDialog(
        site: site,
        run: run,
        existing: _locationOf(site, run),
        fallbackCenter: fallbackCenterFor(_locations, site),
      ),
    );
    if (result == null) return;
    setState(() => _locations = upsertLocation(_locations, result));
    await _persist();
  }

  Future<String?> _promptName({
    required String title,
    required String label,
    String current = '',
    List<String> suggestions = const [],
    String? helper,
  }) async {
    var text = current;
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        void submit() {
          final v = text.trim();
          if (v.isNotEmpty) Navigator.pop(context, v);
        }

        return AlertDialog(
          title: Text(title),
          content: Autocomplete<String>(
            optionsBuilder: (v) {
              if (suggestions.isEmpty) return const [];
              if (v.text.isEmpty || v.text == current) return suggestions;
              return suggestions.where(
                (s) => s.toLowerCase().contains(v.text.toLowerCase()),
              );
            },
            initialValue: TextEditingValue(text: current),
            onSelected: (v) => text = v,
            fieldViewBuilder: (context, fieldController, focusNode, _) {
              return TextField(
                controller: fieldController,
                focusNode: focusNode,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: label,
                  helperText: helper,
                  suffixIcon: ClearButton(fieldController),
                ),
                onChanged: (v) => text = v,
                onSubmitted: (_) => submit(),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            FilledButton(onPressed: submit, child: const Text('OK')),
          ],
        );
      },
    );
    return name;
  }

  // --- Display ---

  String _summary(int count, RunLocation? location) {
    final points = [
      if (location?.hasTakeoff ?? false) 'déco',
      if (location?.hasLanding ?? false) 'atterro',
    ];
    return '$count vol${count > 1 ? 's' : ''} · '
        '${points.isEmpty ? 'pas de GPS' : 'GPS ${points.join(' & ')}'}';
  }

  Widget _gpsIcon(RunLocation? location) {
    final located = location?.hasAny ?? false;
    return Icon(
      located ? Icons.location_on : Icons.location_off,
      size: 20,
      color: located
          ? AppColors.accentOn(context)
          : Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }

  Widget _menu(List<(IconData, String, VoidCallback)> items) =>
      PopupMenuButton<int>(
        icon: const Icon(Icons.more_vert),
        onSelected: (i) => items[i].$3(),
        itemBuilder: (context) => [
          for (var i = 0; i < items.length; i++)
            PopupMenuItem(
              value: i,
              child: Row(
                children: [
                  Icon(items[i].$1, size: 20),
                  const SizedBox(width: 12),
                  Text(items[i].$2),
                ],
              ),
            ),
        ],
      );

  Widget _siteCard(String site) {
    final location = _locationOf(site, '');
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.only(left: 16, right: 4),
            leading: _gpsIcon(location),
            minLeadingWidth: 20,
            title: Text(
              site,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(_summary(_flightCount(site), location)),
            onTap: () => _editLocation(site, ''),
            trailing: _menu([
              (
                Icons.add_location_alt_outlined,
                'Coordonnées GPS',
                () => _editLocation(site, ''),
              ),
              if (location?.hasAny ?? false)
                (Icons.ios_share, 'Partager', () => _share(site, '')),
              (Icons.add, 'Ajouter un run', () => _addRun(site)),
              (
                Icons.drive_file_rename_outline,
                'Renommer / fusionner',
                () => _renameSite(site),
              ),
              (Icons.delete_outline, 'Supprimer', () => _deleteSite(site)),
            ]),
          ),
          for (final run in _runsOf(site)) ...[
            Divider(height: 1, indent: 52, color: cs.outlineVariant),
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.only(left: 52, right: 4),
              leading: _gpsIcon(_locationOf(site, run)),
              minLeadingWidth: 20,
              title: Text(run),
              subtitle: Text(
                _summary(_flightCount(site, run), _locationOf(site, run)),
              ),
              onTap: () => _editLocation(site, run),
              trailing: _menu([
                (
                  Icons.add_location_alt_outlined,
                  'Coordonnées GPS',
                  () => _editLocation(site, run),
                ),
                if (_locationOf(site, run)?.hasAny ?? false)
                  (Icons.ios_share, 'Partager', () => _share(site, run)),
                (
                  Icons.drive_file_rename_outline,
                  'Renommer / fusionner',
                  () => _renameRun(site, run),
                ),
                (
                  Icons.delete_outline,
                  'Supprimer',
                  () => _deleteRun(site, run),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final query = _search.text.trim().toLowerCase();
    final shown = query.isEmpty
        ? _sites
        : _sites
              .where(
                (s) =>
                    s.toLowerCase().contains(query) ||
                    _runsOf(s).any((r) => r.toLowerCase().contains(query)),
              )
              .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Sites & runs')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: TextField(
                    controller: _search,
                    decoration: InputDecoration(
                      hintText: 'Rechercher un site ou un run',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: ClearButton(_search),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                  child: Text(
                    '${_sites.length} sites · les runs (lignes de speedflying) '
                    'sont sous leur site',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
                if (shown.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      query.isEmpty
                          ? 'Aucun site.\nAjoute-en un avec +.'
                          : 'Aucun site ni run trouvé.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                for (final site in shown) _siteCard(site),
              ],
            ),
      floatingActionButton: _loading
          ? null
          : FloatingActionButton(
              tooltip: 'Nouveau site',
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              onPressed: _addSite,
              child: const Icon(Icons.add),
            ),
    );
  }
}
