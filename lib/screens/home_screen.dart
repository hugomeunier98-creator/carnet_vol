import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../models/discipline.dart';
import '../models/flight_entry.dart';
import '../widgets/discipline_icon.dart';
import '../widgets/page_colors.dart';
import '../services/app_update.dart';
import '../services/backup_service.dart';
import '../services/export_service.dart';
import '../services/storage_service.dart';
import '../utils/date_format.dart';
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

  late final TabController _tabController = TabController(
    length: _tabDisciplines.length,
    vsync: this,
  )..addListener(() => setState(() {}));

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
      final from = _filterDateFrom;
      if (from != null && f.date.isBefore(from)) return false;
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
    messenger.showMaterialBanner(
      MaterialBanner(
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
      ),
    );
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
        final used =
            _flights
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
              title: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final d in Discipline.values)
              ListTile(
                leading: DisciplineIcon(d, color: AppColors.accent),
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

  /// JSON: every piece of data (flights of all disciplines, GPS points,
  /// names), which "Importer un fichier" reads back in full. CSV: the
  /// visible tab's flights, for spreadsheets.
  Future<void> _handleExport(String format) async {
    if (format == 'json') {
      final backup = await _backup.load();
      await _export.exportToFile(
        backup.toJson(),
        Backup.fileName(DateTime.now()),
        mimeType: 'application/json',
      );
      return;
    }
    final discipline = _tabDiscipline;
    final flights = discipline == null
        ? _flights
        : _flights.where((f) => f.discipline == discipline).toList();
    final suffix = discipline == null ? '' : '_${discipline.name}';
    await _export.exportToFile(
      _export.toCsv(flights),
      'carnet_de_vol$suffix.csv',
      mimeType: 'text/csv',
    );
  }

  final _backup = BackupService();

  Future<void> _handleImportFile() async {
    final discipline = await _resolveDiscipline(
      'Discipline des vols importés (si le fichier ne la précise pas)',
    );
    if (discipline == null) return;
    final imported = await _export.importFromFile(discipline);
    if (imported == null) return;
    await _backup.mergeRunLocations(imported.runLocations);
    setState(() {
      _sites = {..._sites, ...imported.sites}.toList()..sort();
      _runs = {..._runs, ...imported.runs}.toList()..sort();
      _wings = {..._wings, ...imported.wings}.toList()..sort();
    });
    _mergeImported(imported.flights, gpsPoints: imported.runLocations.length);
  }

  Future<void> _handleImportFromNotes() async {
    final discipline = await _resolveDiscipline('Discipline des vols importés');
    if (discipline == null || !mounted) return;
    final imported = await Navigator.of(context).push<List<FlightEntry>>(
      MaterialPageRoute(
        builder: (_) => PageColors(
          top: AppColors.accent,
          child: NotesImportScreen(discipline: discipline),
        ),
      ),
    );
    if (imported == null) return;
    _mergeImported(imported);
  }

  Future<void> _handleManageNames() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const PageColors(
          top: AppColors.accent,
          child: ManageNamesScreen(),
        ),
      ),
    );
    await _load();
  }

  void _mergeImported(List<FlightEntry> imported, {int gpsPoints = 0}) {
    setState(() {
      for (final entry in imported) {
        // The same flight (exported then imported back), else the same
        // number in the same discipline (a re-pasted Notes table: parapente
        // #12 is not speedflying #12).
        var idx = _flights.indexWhere((f) => f.id == entry.id);
        if (idx < 0 && entry.sourceNumber != null) {
          idx = _flights.indexWhere(
            (f) =>
                f.discipline == entry.discipline &&
                f.sourceNumber == entry.sourceNumber,
          );
        }
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
        SnackBar(
          content: Text(
            '${imported.length} vol(s) importé(s)'
            '${gpsPoints > 0 ? ', $gpsPoints point(s) GPS' : ''}',
          ),
        ),
      );
    }
  }

  String _formatDateRange() {
    String fmt(DateTime d) => formatNumericDate(d);
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
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 0,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Filtrer les vols',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
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
          },
        );
      },
    );
  }

  Widget _filterDateField({
    required BuildContext context,
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime?> onChanged,
  }) {
    final text = value == null ? 'Toutes' : formatNumericDate(value);
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
        ...options.map(
          (o) => DropdownMenuItem<String?>(value: o, child: Text(o)),
        ),
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
    final accent = AppColors.accent;

    return PageColors(
      top: AppColors.accent,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 64,
          backgroundColor: AppColors.accent,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
          ),
          title: Text(
            'Carnet de vol',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Filtrer',
              onPressed: _openFilterSheet,
              icon: Badge(
                isLabelVisible: _hasActiveFilters,
                smallSize: 8,
                child: Icon(
                  _hasActiveFilters
                      ? Icons.filter_alt
                      : Icons.filter_alt_outlined,
                ),
              ),
            ),
            _buildMenu(),
            const SizedBox(width: 4),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: _DisciplineSwitcher(
              controller: _tabController,
              disciplines: _tabDisciplines,
            ),
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            for (final d in _tabDisciplines) _buildTab(d, numberLabels),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _createFlight,
          backgroundColor: accent,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text(
            'Nouveau vol',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _buildMenu() {
    PopupMenuItem<String> item(String value, IconData icon, String text) =>
        PopupMenuItem(
          value: value,
          child: Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 12),
              Flexible(child: Text(text)),
            ],
          ),
        );
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
          item('import_notes', Icons.content_paste, 'Importer depuis Notes'),
          item('import_file', Icons.file_open_outlined, 'Importer un fichier'),
          const PopupMenuDivider(),
          item(
            'export_csv',
            Icons.table_chart_outlined,
            'Exporter en CSV ($tab)',
          ),
          item(
            'export_json',
            Icons.data_object,
            'Exporter en JSON (toutes les données)',
          ),
          const PopupMenuDivider(),
          item('manage_names', Icons.merge_type, 'Gérer les sites & runs'),
          item(
            'check_update',
            Icons.system_update_outlined,
            'Rechercher une mise à jour',
          ),
        ];
      },
    );
  }

  /// One tab's content; [discipline] is null for "Tout".
  Widget _buildTab(Discipline? discipline, Map<String, String> numberLabels) {
    final filtered = _filteredFlights(discipline);
    final months = _groupByMonth(filtered);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: _SummaryCard(discipline: discipline, flights: filtered),
          ),
        ),
        if (_hasActiveFilters) SliverToBoxAdapter(child: _buildFilterChips()),
        if (filtered.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyState(
              filtered: _hasActiveFilters,
              onClearFilters: _clearFilters,
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            sliver: SliverList.builder(
              itemCount: months.length,
              itemBuilder: (context, index) => _MonthSection(
                flights: months[index],
                numberLabels: numberLabels,
                showDiscipline: discipline == null,
                onTap: _openDetail,
              ),
            ),
          ),
      ],
    );
  }

  /// Splits newest-first flights into consecutive same-month groups.
  static List<List<FlightEntry>> _groupByMonth(List<FlightEntry> flights) {
    final groups = <List<FlightEntry>>[];
    for (final f in flights) {
      final last = groups.isEmpty ? null : groups.last.first.date;
      if (last != null &&
          last.year == f.date.year &&
          last.month == f.date.month) {
        groups.last.add(f);
      } else {
        groups.add([f]);
      }
    }
    return groups;
  }

  void _clearFilters() => setState(() {
    _filterSite = null;
    _filterRun = null;
    _filterWing = null;
    _filterDateFrom = null;
    _filterDateTo = null;
    _filterHasComment = false;
  });

  Widget _buildFilterChips() {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          for (final chip in [
            if (_filterSite != null)
              ('Site : $_filterSite', () => setState(() => _filterSite = null)),
            if (_filterRun != null)
              ('Run : $_filterRun', () => setState(() => _filterRun = null)),
            if (_filterWing != null)
              (
                'Voile : $_filterWing',
                () => setState(() => _filterWing = null),
              ),
            if (_filterDateFrom != null || _filterDateTo != null)
              (
                _formatDateRange(),
                () => setState(() {
                  _filterDateFrom = null;
                  _filterDateTo = null;
                }),
              ),
            if (_filterHasComment)
              (
                'Avec commentaire',
                () => setState(() => _filterHasComment = false),
              ),
          ])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InputChip(
                label: Text(chip.$1),
                onDeleted: chip.$2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          TextButton(
            onPressed: _clearFilters,
            child: const Text('Tout effacer'),
          ),
        ],
      ),
    );
  }
}

/// Pill-shaped segmented control over the discipline tabs.
class _DisciplineSwitcher extends StatelessWidget {
  final TabController controller;
  final List<Discipline?> disciplines;

  const _DisciplineSwitcher({
    required this.controller,
    required this.disciplines,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TabBar(
        controller: controller,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(11),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        splashBorderRadius: BorderRadius.circular(11),
        labelColor: AppColors.accent,
        unselectedLabelColor: Colors.white.withValues(alpha: 0.9),
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        tabs: [
          for (final d in disciplines)
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (d != null) ...[
                    DisciplineIcon(d, size: 18),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      d?.label ?? 'Tout',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Headline numbers for the visible tab, on the discipline's colour.
class _SummaryCard extends StatelessWidget {
  final Discipline? discipline;
  final List<FlightEntry> flights;

  const _SummaryCard({required this.discipline, required this.flights});

  @override
  Widget build(BuildContext context) {
    int countOf(Iterable<FlightEntry> list) =>
        list.fold<int>(0, (sum, f) => sum + f.count);
    final now = DateTime.now();
    final total = countOf(flights);
    final thisYear = countOf(flights.where((f) => f.date.year == now.year));
    final sites = flights.map((f) => f.site).toSet().length;
    // Flights are newest-first.
    final last = flights.isEmpty ? null : flights.first.date;

    final stats = discipline == null
        ? [
            for (final d in Discipline.values)
              (d.label, '${countOf(flights.where((f) => f.discipline == d))}'),
            ('Dernier vol', last == null ? '–' : formatSince(last, now)),
          ]
        : [
            ('Sites', '$sites'),
            ('En ${now.year}', '$thisYear'),
            ('Dernier vol', last == null ? '–' : formatSince(last, now)),
          ];

    final cs = Theme.of(context).colorScheme;
    final accent =
AppColors.accentOn(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$total',
                  style: TextStyle(
                    color: accent,
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  total > 1 ? 'vols' : 'vol',
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (discipline != null)
                  DisciplineIcon(
                    discipline!,
                    size: 34,
                    color: accent.withValues(alpha: 0.3),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                for (final (label, value) in stats)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A month's flights: a small header, then the flights in one rounded group.
class _MonthSection extends StatelessWidget {
  final List<FlightEntry> flights;
  final Map<String, String> numberLabels;
  final bool showDiscipline;
  final ValueChanged<FlightEntry> onTap;

  const _MonthSection({
    required this.flights,
    required this.numberLabels,
    required this.showDiscipline,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final count = flights.fold<int>(0, (sum, f) => sum + f.count);
    final headerStyle = Theme.of(context).textTheme.labelLarge
        ?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    formatMonthYear(flights.first.date),
                    style: headerStyle,
                  ),
                ),
                Text(
                  '$count vol${count > 1 ? 's' : ''}',
                  style: headerStyle?.copyWith(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Card(
            child: Column(
              children: [
                for (var i = 0; i < flights.length; i++) ...[
                  if (i > 0) const Divider(indent: 72),
                  _FlightTile(
                    entry: flights[i],
                    numberLabel: numberLabels[flights[i].id],
                    showDiscipline: showDiscipline,
                    onTap: () => onTap(flights[i]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FlightTile extends StatelessWidget {
  final FlightEntry entry;
  final String? numberLabel;
  final VoidCallback onTap;

  /// On "Tout", names the discipline next to the wing so the two kinds of
  /// flights stay distinct within the same list (the date badge already
  /// carries its colour everywhere).
  final bool showDiscipline;

  const _FlightTile({
    required this.entry,
    required this.numberLabel,
    required this.onTap,
    this.showDiscipline = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final discipline = entry.discipline;
    final muted = text.bodySmall?.copyWith(color: cs.onSurfaceVariant);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
        child: Row(
          children: [
            _DateBadge(date: entry.date, color: AppColors.accentOn(context)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: entry.site,
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (entry.run.isNotEmpty)
                          TextSpan(
                            text: '  ${entry.run}',
                            style: text.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (showDiscipline) ...[
                        DisciplineIcon(
                          discipline,
                          size: 14,
                          color: AppColors.accentOn(context),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Flexible(
                        child: Text(
                          entry.wing,
                          style: muted,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (entry.comment.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 13,
                          color: cs.onSurfaceVariant,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  numberLabel ?? '',
                  style: text.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (entry.count > 1) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '×${entry.count}',
                      style: text.labelSmall?.copyWith(
                        color: AppColors.accentOn(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Calendar-style day/month badge, tinted with the discipline's colour.
class _DateBadge extends StatelessWidget {
  final DateTime date;
  final Color color;

  const _DateBadge({required this.date, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 48,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${date.day}',
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          Text(
            formatShortMonth(date),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool filtered;
  final VoidCallback onClearFilters;

  const _EmptyState({required this.filtered, required this.onClearFilters});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 96),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              filtered ? Icons.filter_alt_off_outlined : Icons.paragliding,
              size: 42,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            filtered ? 'Aucun vol ne correspond' : 'Aucun vol pour le moment',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            filtered ? 'Essaie de retirer un filtre.' : 'Ajoute ton premier vol avec « Nouveau vol », ou importe ton carnet depuis le menu ⋯.',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          if (filtered) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: onClearFilters,
              child: const Text('Effacer les filtres'),
            ),
          ],
        ],
      ),
    );
  }
}
