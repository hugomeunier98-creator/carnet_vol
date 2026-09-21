import 'package:flutter/material.dart';

import '../models/flight_entry.dart';
import '../services/export_service.dart';
import '../services/storage_service.dart';
import '../utils/flight_numbering.dart';
import 'flight_detail_screen.dart';
import 'flight_form_screen.dart';
import 'media_import_screen.dart';
import 'notes_import_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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

  List<FlightEntry> get _filteredFlights {
    return _flights.where((f) {
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
    _load();
  }

  Future<void> _load() async {
    final flights = await _storage.loadFlights();
    final sites = await _storage.loadSites();
    final runs = await _storage.loadRuns();
    final wings = await _storage.loadWings();
    flights.sort((a, b) => b.date.compareTo(a.date));
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

  Future<void> _createFlight() async {
    final result = await Navigator.of(context).push<Object>(
      MaterialPageRoute(
        builder: (_) => FlightFormScreen(
          knownSites: _sites,
          knownRuns: _runs,
          knownWings: _wings,
        ),
      ),
    );
    if (result is! FlightEntry) return;
    setState(() {
      _flights.add(result);
      _rememberReferences(result);
      _flights.sort((a, b) => b.date.compareTo(a.date));
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
          knownWings: _wings,
          onUpdated: (updated) async {
            setState(() {
              final idx = _flights.indexWhere((f) => f.id == updated.id);
              if (idx >= 0) _flights[idx] = updated;
              _rememberReferences(updated);
              _flights.sort((a, b) => b.date.compareTo(a.date));
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

  Future<void> _handleExport(String format) async {
    final content =
        format == 'csv' ? _export.toCsv(_flights) : _export.toJson(_flights);
    final name = format == 'csv' ? 'carnet_de_vol.csv' : 'carnet_de_vol.json';
    await _export.exportToFile(content, name);
  }

  Future<void> _handleImportFile() async {
    final imported = await _export.importFromFile();
    if (imported == null) return;
    _mergeImported(imported);
  }

  Future<void> _handleImportFromNotes() async {
    final imported = await Navigator.of(context).push<List<FlightEntry>>(
      MaterialPageRoute(builder: (_) => const NotesImportScreen()),
    );
    if (imported == null) return;
    _mergeImported(imported);
  }

  Future<void> _handleImportMedia() async {
    final count = await Navigator.of(context).push<int>(
      MaterialPageRoute(builder: (_) => MediaImportScreen(flights: _flights)),
    );
    if (count == null || !mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$count média(s) importé(s)')));
  }

  void _mergeImported(List<FlightEntry> imported) {
    setState(() {
      for (final entry in imported) {
        final idx = entry.sourceNumber != null
            ? _flights.indexWhere((f) => f.sourceNumber == entry.sourceNumber)
            : _flights.indexWhere((f) => f.id == entry.id);
        if (idx >= 0) {
          _flights[idx] = entry;
        } else {
          _flights.add(entry);
        }
        _rememberReferences(entry);
      }
      _flights.sort((a, b) => b.date.compareTo(a.date));
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

    final filtered = _filteredFlights;
    final numberLabels = _numberLabels;
    final totalFlights = filtered.fold<int>(0, (sum, f) => sum + f.count);
    final siteCount = filtered.map((f) => f.site).toSet().length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Carnet de vol'),
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
              if (value == 'import_media') _handleImportMedia();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                  value: 'import_notes',
                  child: Text('Importer depuis Notes (coller)')),
              PopupMenuItem(value: 'import_file', child: Text('Importer un fichier')),
              PopupMenuItem(
                  value: 'import_media',
                  child: Text('Importer des médias (photos/vidéos)')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'export_csv', child: Text('Exporter en CSV')),
              PopupMenuItem(value: 'export_json', child: Text('Exporter en JSON')),
            ],
          ),
        ],
      ),
      body: Column(
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
                _StatItem(label: 'Vols', value: '$totalFlights'),
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
                        onTap: () => _openDetail(f),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createFlight,
        child: const Icon(Icons.add),
      ),
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

  const _FlightRow({required this.entry, required this.numberLabel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final date = entry.date;
    final dateStr =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${(date.year % 100).toString().padLeft(2, '0')}';
    final location =
        entry.run.isNotEmpty ? '${entry.site} · ${entry.run}' : entry.site;
    final details = [
      entry.wing,
      if (entry.verticalOrDuration.isNotEmpty) entry.verticalOrDuration,
    ].join(' · ');

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                child: Text(
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
                width: 52,
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
