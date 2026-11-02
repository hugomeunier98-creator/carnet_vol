import 'package:flutter/material.dart';

import '../models/discipline.dart';
import '../models/flight_entry.dart';
import '../services/app_update.dart';
import '../services/export_service.dart';
import '../services/storage_service.dart';
import '../utils/flight_numbering.dart';
import 'flight_detail_screen.dart';
import 'flight_form_screen.dart';
import 'manage_names_screen.dart';
import 'notes_import_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  /// Tabs: one per discipline, then "Tout" (every flight, by date).
  static const _tabDisciplines = <Discipline?>[...Discipline.values, null];

  late final TabController _tabController =
      TabController(length: _tabDisciplines.length, vsync: this)
        ..addListener(() => setState(() {}));

  /// Discipline of the visible tab; null on "Tout".
  Discipline? get _tabDiscipline => _tabDisciplines[_tabController.index];

  final _storage = StorageService();
  final _export = ExportService();

  List<FlightEntry> _flights = [];
  List<String> _sites = [];
  List<String> _runs = [];
  List<String> _wings = [];
  bool _loading = true;

  String? _filterSite;
  String? _filterRun;
  String? _filterWing;
  DateTime? _filterDateFrom;
  DateTime? _filterDateTo;
  bool _filterHasComment = false;

  Map<String, String> get _numberLabels => computeFlightNumberLabels(_flights);

  bool get _hasActiveFilters =>
      _filterSite != null ||
      _filterRun != null ||
      _filterWing != null ||
      _filterDateFrom != null ||
      _filterDateTo != null ||
      _filterHasComment;

  List<FlightEntry> _filteredFlights(Discipline? discipline) {
    return _flights.where((f) {
      if (discipline != null && f.discipline != discipline) return false;
      if (_filterSite != null && f.site != _filterSite) return false;
      if (_filterRun != null && f.run != _filterRun) return false;
      if (_filterWing != null && f.wing != _filterWing) return false;
      if (_filterDateFrom != null && f.date.isBefore(_filterDateFrom!)) return false;
      if (_filterDateTo != null && f.date.isAfter(_filterDateTo!)) return false;
      if (_filterHasComment && f.comment.trim().isEmpty) return false;
      return true;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A launch already updates on its own (web/index.html); this covers
    // coming back to an app left open in the background.
    if (state == AppLifecycleState.resumed) _offerUpdateIfAvailable();
  }

  bool _updateBannerShown = false;

  Future<void> _offerUpdateIfAvailable() async {
    final current = AppUpdate.currentBuild;
    if (current == null || _updateBannerShown) return;
    final latest = await AppUpdate.latestBuild();
    if (latest == null || latest == current || !mounted) return;
    _updateBannerShown = true;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showMaterialBanner(MaterialBanner(
      content: const Text('Nouvelle version disponible'),
      leading: const Icon(Icons.system_update),
      actions: [
        TextButton(
          onPressed: () {
            messenger.hideCurrentMaterialBanner();
            _updateBannerShown = false;
          },
          child: const Text('Plus tard'),
        ),
        FilledButton(
          onPressed: AppUpdate.apply,
          child: const Text('Mettre à jour'),
        ),
      ],
    ));
  }

  Future<void> _handleCheckUpdate() async {
    final messenger = ScaffoldMessenger.of(context);
    void say(String text) =>
        messenger.showSnackBar(SnackBar(content: Text(text)));
    final current = AppUpdate.currentBuild;
    if (current == null) {
      say('Version de développement : pas de mise à jour à vérifier');
      return;
    }
    final latest = await AppUpdate.latestBuild();
    if (latest == null) {
      say('Impossible de vérifier (hors ligne ?)');
    } else if (latest == current) {
      say('Application à jour (version $current)');
    } else {
      say('Mise à jour en cours…');
      await AppUpdate.apply();
    }
  }

  Future<void> _load() async {
    // Run independent reads in parallel instead of one after another - the
    // flights/sites/runs/wings reads don't depend on each other at all.
    final results = await Future.wait([
      _storage.loadFlights(),
      _storage.loadSites(),
      _storage.loadRuns(),
      _storage.loadWings(),
    ]);
    final flights = results[0] as List<FlightEntry>;
    final sites = results[1] as List<String>;
    final runs = results[2] as List<String>;
    final wings = results[3] as List<String>;
    flights.sort(compareNewestFirst);
    if (!mounted) return;
    setState(() {
      _flights = flights;
      _sites = sites;
      _runs = runs;
      _wings = wings;
      _loading = false;
    });
  }

  Future<void> _persist() async {
    await _storage.saveFlights(_flights);
    await _storage.saveSites(_sites);
    await _storage.saveRuns(_runs);
    await _storage.saveWings(_wings);
  }

  void _rememberReferences(FlightEntry entry) {
    if (entry.site.isNotEmpty && !_sites.contains(entry.site)) {
      _sites = [..._sites, entry.site]..sort();
    }
    if (entry.run.isNotEmpty && !_runs.contains(entry.run)) {
      _runs = [..._runs, entry.run]..sort();
    }
    if (entry.wing.isNotEmpty && !_wings.contains(entry.wing)) {
      _wings = [..._wings, entry.wing]..sort();
    }
  }

  /// Wing suggestions per discipline: the wings already flown in it, or
  /// every known wing while that discipline has no flight yet.
  Map<Discipline, List<String>> get _wingsByDiscipline => {
        for (final d in Discipline.values)
          d: () {
            final used = _flights
                .where((f) => f.discipline == d && f.wing.isNotEmpty)
                .map((f) => f.wing)
                .toSet()
                .toList()
              ..sort();
            return used.isEmpty ? _wings : used;
          }(),
      };

  /// The visible tab's discipline, or asks for one on "Tout".
  Future<Discipline?> _resolveDiscipline(String title) async {
    final current = _tabDiscipline;
    if (current != null) return current;
    return showModalBottomSheet<Discipline>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(title, style: Theme.of(context).textTheme.titleMedium),
            ),
            for (final d in Discipline.values)
              ListTile(
                leading: Icon(d.icon, color: d.color),
                title: Text(d.label),
                onTap: () => Navigator.of(context).pop(d),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _createFlight() async {
    final discipline = await _resolveDiscipline('Nouveau vol');
    if (discipline == null || !mounted) return;
    final result = await Navigator.of(context).push<Object>(
      MaterialPageRoute(
        builder: (_) => FlightFormScreen(
          discipline: discipline,
          knownSites: _sites,
          knownRuns: _runs,
          knownWings: _wingsByDiscipline,
        ),
      ),
    );
    if (result is! FlightEntry) return;
    setState(() {
      _flights.add(result);
      _rememberReferences(result);
      _flights.sort(compareNewestFirst);
    });
    await _persist();
  }

  Future<void> _openDetail(FlightEntry existing) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FlightDetailScreen(
          entry: existing,
          allFlights: _flights,
          knownSites: _sites,
          knownRuns: _runs,
          knownWings: _wingsByDiscipline,
          onUpdated: (updated) async {
            setState(() {
              final idx = _flights.indexWhere((f) => f.id == updated.id);
              if (idx >= 0) _flights[idx] = updated;
              _rememberReferences(updated);
              _flights.sort(compareNewestFirst);
            });
            await _persist();
          },
          onDeleted: () async {
            setState(() => _flights.removeWhere((f) => f.id == existing.id));
            await _persist();
          },
        ),
      ),
    );
  }

  /// Exports the visible tab's flights ("Tout": every flight).
  Future<void> _handleExport(String format) async {
    final discipline = _tabDiscipline;
    final flights = discipline == null
        ? _flights
        : _flights.where((f) => f.discipline == discipline).toList();
    final content =
        format == 'csv' ? _export.toCsv(flights) : _export.toJson(flights);
    final suffix = discipline == null ? '' : '_${discipline.name}';
    await _export.exportToFile(content, 'carnet_de_vol$suffix.$format');
  }

  Future<void> _handleImportFile() async {
    final discipline = await _resolveDiscipline(
        'Discipline des vols importés (si le fichier ne la précise pas)');
    if (discipline == null) return;
    final imported = await _export.importFromFile(discipline);
    if (imported == null) return;
    _mergeImported(imported);
  }

  Future<void> _handleImportFromNotes() async {
    final discipline = await _resolveDiscipline('Discipline des vols importés');
    if (discipline == null || !mounted) return;
    final imported = await Navigator.of(context).push<List<FlightEntry>>(
      MaterialPageRoute(builder: (_) => NotesImportScreen(discipline: discipline)),
    );
    if (imported == null) return;
    _mergeImported(imported);
  }


  Future<void> _handleManageNames() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ManageNamesScreen()),
    );
    await _load();
  }

  void _mergeImported(List<FlightEntry> imported) {
    setState(() {
      for (final entry in imported) {
        // Numbers are per discipline: parapente #12 is not speedflying #12.
        final idx = entry.sourceNumber != null
            ? _flights.indexWhere((f) =>
                f.discipline == entry.discipline &&
                f.sourceNumber == entry.sourceNumber)
            : _flights.indexWhere((f) => f.id == entry.id);
        if (idx >= 0) {
          _flights[idx] = entry;
        } else {
          _flights.add(entry);
        }
        _rememberReferences(entry);
      }
      _flights.sort(compareNewestFirst);
    });
    _persist();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${imported.length} vol(s) importé(s)')),
      );
    }
  }

  String _formatDateRange() {
    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    if (_filterDateFrom != null && _filterDateTo != null) {
      return '${fmt(_filterDateFrom!)} - ${fmt(_filterDateTo!)}';
    }
    if (_filterDateFrom != null) return 'depuis ${fmt(_filterDateFrom!)}';
    return "jusqu'au ${fmt(_filterDateTo!)}";
  }

  Future<void> _openFilterSheet() async {
    String? site = _filterSite;
    String? run = _filterRun;
    String? wing = _filterWing;
    DateTime? dateFrom = _filterDateFrom;
    DateTime? dateTo = _filterDateTo;
    bool hasComment = _filterHasComment;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Filtrer les vols', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                _filterDropdown(
                  label: 'Site',
                  value: site,
                  options: _sites,
                  onChanged: (v) => setModalState(() => site = v),
                ),
                const SizedBox(height: 12),
                _filterDropdown(
                  label: 'Run',
                  value: run,
                  options: _runs,
                  onChanged: (v) => setModalState(() => run = v),
                ),
                const SizedBox(height: 12),
                _filterDropdown(
                  label: 'Voile',
                  value: wing,
                  options: _wings,
                  onChanged: (v) => setModalState(() => wing = v),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _filterDateField(
                        context: context,
                        label: 'Du',
                        value: dateFrom,
                        onChanged: (v) => setModalState(() => dateFrom = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _filterDateField(
                        context: context,
                        label: 'Au',
                        value: dateTo,
                        onChanged: (v) => setModalState(() => dateTo = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Avec commentaire uniquement'),
                  value: hasComment,
                  onChanged: (v) => setModalState(() => hasComment = v),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setModalState(() {
                          site = null;
                          run = null;
                          wing = null;
                          dateFrom = null;
                          dateTo = null;
                          hasComment = false;
                        }),
                        child: const Text('Réinitialiser'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          setState(() {
                            _filterSite = site;
                            _filterRun = run;
                            _filterWing = wing;
                            _filterDateFrom = dateFrom;
                            _filterDateTo = dateTo;
                            _filterHasComment = hasComment;
                          });
                          Navigator.of(context).pop();
                        },
                        child: const Text('Appliquer'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Widget _filterDateField({
    required BuildContext context,
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime?> onChanged,
  }) {
    final text = value == null
        ? 'Toutes'
        : '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime.now().add(const Duration(days: 1)),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: value == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => onChanged(null),
                ),
        ),
        child: Text(text),
      ),
    );
  }

  Widget _filterDropdown({
    required String label,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String?>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('Tous')),
        ...options.map((o) => DropdownMenuItem<String?>(value: o, child: Text(o))),
      ],
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final numberLabels = _numberLabels;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Carnet de vol'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            for (final d in _tabDisciplines)
              Tab(
                height: 56,
                icon: Icon(d?.icon ?? Icons.list_alt, size: 20),
                text: d?.label ?? 'Tout',
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Filtrer',
            onPressed: _openFilterSheet,
            icon: Badge(
              isLabelVisible: _hasActiveFilters,
              smallSize: 8,
              child: Icon(_hasActiveFilters ? Icons.filter_alt : Icons.filter_alt_outlined),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'export_csv') _handleExport('csv');
              if (value == 'export_json') _handleExport('json');
              if (value == 'import_file') _handleImportFile();
              if (value == 'import_notes') _handleImportFromNotes();
              if (value == 'manage_names') _handleManageNames();
              if (value == 'check_update') _handleCheckUpdate();
            },
            itemBuilder: (context) {
              final tab = _tabDiscipline?.label ?? 'tous les vols';
              return [
                const PopupMenuItem(
                    value: 'import_notes',
                    child: Text('Importer depuis Notes (coller)')),
                const PopupMenuItem(
                    value: 'import_file', child: Text('Importer un fichier')),
                const PopupMenuDivider(),
                PopupMenuItem(
                    value: 'export_csv', child: Text('Exporter en CSV ($tab)')),
                PopupMenuItem(
                    value: 'export_json', child: Text('Exporter en JSON ($tab)')),
                const PopupMenuDivider(),
                const PopupMenuItem(
                    value: 'manage_names',
                    child: Text('Gérer les sites & runs (fusionner)')),
                const PopupMenuDivider(),
                const PopupMenuItem(
                    value: 'check_update',
                    child: Text('Rechercher une mise à jour')),
              ];
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          for (final d in _tabDisciplines) _buildTab(d, numberLabels),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createFlight,
        backgroundColor: _tabDiscipline?.color,
        foregroundColor: _tabDiscipline == null ? null : Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  /// One tab's content; [discipline] is null for "Tout".
  Widget _buildTab(Discipline? discipline, Map<String, String> numberLabels) {
    final filtered = _filteredFlights(discipline);
    int countOf(Iterable<FlightEntry> flights) =>
        flights.fold<int>(0, (sum, f) => sum + f.count);
    final siteCount = filtered.map((f) => f.site).toSet().length;

    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem(label: 'Vols', value: '${countOf(filtered)}'),
              if (discipline == null)
                for (final d in Discipline.values)
                  _StatItem(
                    label: d.label,
                    value: '${countOf(filtered.where((f) => f.discipline == d))}',
                  )
              else
                _StatItem(label: 'Sites', value: '$siteCount'),
            ],
          ),
        ),
        if (_hasActiveFilters)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (_filterSite != null)
                  InputChip(
                    label: Text('Site : $_filterSite'),
                    onDeleted: () => setState(() => _filterSite = null),
                  ),
                if (_filterRun != null)
                  InputChip(
                    label: Text('Run : $_filterRun'),
                    onDeleted: () => setState(() => _filterRun = null),
                  ),
                if (_filterWing != null)
                  InputChip(
                    label: Text('Voile : $_filterWing'),
                    onDeleted: () => setState(() => _filterWing = null),
                  ),
                if (_filterDateFrom != null || _filterDateTo != null)
                  InputChip(
                    label: Text('Date : ${_formatDateRange()}'),
                    onDeleted: () => setState(() {
                      _filterDateFrom = null;
                      _filterDateTo = null;
                    }),
                  ),
                if (_filterHasComment)
                  InputChip(
                    label: const Text('Avec commentaire'),
                    onDeleted: () => setState(() => _filterHasComment = false),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: filtered.isEmpty
              ? _EmptyState(filtered: _hasActiveFilters)
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final f = filtered[index];
                    return _FlightRow(
                      entry: f,
                      numberLabel: numberLabels[f.id],
                      showDiscipline: discipline == null,
                      onTap: () => _openDetail(f),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final onColor = Theme.of(context).colorScheme.onPrimaryContainer;
    return Column(
      children: [
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(color: onColor, fontWeight: FontWeight.bold)),
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: onColor)),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool filtered;

  const _EmptyState({this.filtered = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            filtered ? Icons.filter_alt_off_outlined : Icons.paragliding_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            filtered ? 'Aucun vol ne correspond à ce filtre' : 'Aucun vol enregistré',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(filtered
              ? 'Essaie de retirer un filtre'
              : 'Appuie sur + pour ajouter ton premier vol'),
        ],
      ),
    );
  }
}

class _FlightRow extends StatelessWidget {
  final FlightEntry entry;
  final String? numberLabel;
  final VoidCallback onTap;

  /// On "Tout", marks the discipline with its colour and icon so the two
  /// kinds of flights stay distinct within the same list.
  final bool showDiscipline;

  const _FlightRow({
    required this.entry,
    required this.numberLabel,
    required this.onTap,
    this.showDiscipline = false,
  });

  @override
  Widget build(BuildContext context) {
    final date = entry.date;
    final dateStr =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${(date.year % 100).toString().padLeft(2, '0')}';
    final location =
        entry.run.isNotEmpty ? '${entry.site} · ${entry.run}' : entry.site;
    final details = entry.wing;
    final discipline = entry.discipline;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          decoration: showDiscipline
              ? BoxDecoration(
                  border: Border(left: BorderSide(color: discipline.color, width: 5)),
                )
              : null,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                child: showDiscipline
                    ? Column(
                        children: [
                          Icon(discipline.icon, size: 18, color: discipline.color),
                          Text(
                            numberLabel ?? '',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: discipline.color),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      )
                    : Text(
                  numberLabel ?? '',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey.shade500),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(
                width: 60,
                child: Text(dateStr,
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(location,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (entry.count > 1)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('×${entry.count}',
                                style: Theme.of(context).textTheme.bodySmall),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(details, style: Theme.of(context).textTheme.bodySmall),
                    if (entry.comment.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(entry.comment,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontStyle: FontStyle.italic),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
