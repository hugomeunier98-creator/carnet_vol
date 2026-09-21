import 'package:flutter/material.dart';

import '../models/flight_entry.dart';
import '../services/export_service.dart';
import '../services/storage_service.dart';
import 'flight_form_screen.dart';
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

  Future<void> _openForm({FlightEntry? existing}) async {
    final result = await Navigator.of(context).push<Object>(
      MaterialPageRoute(
        builder: (_) => FlightFormScreen(
          existing: existing,
          knownSites: _sites,
          knownRuns: _runs,
          knownWings: _wings,
        ),
      ),
    );
    if (result == null) return;
    if (result == 'delete' && existing != null) {
      setState(() => _flights.removeWhere((f) => f.id == existing.id));
      await _persist();
      return;
    }
    if (result is FlightEntry) {
      setState(() {
        if (existing != null) {
          final idx = _flights.indexWhere((f) => f.id == existing.id);
          _flights[idx] = result;
        } else {
          _flights.add(result);
        }
        _rememberReferences(result);
        _flights.sort((a, b) => b.date.compareTo(a.date));
      });
      await _persist();
    }
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final totalFlights = _flights.fold<int>(0, (sum, f) => sum + f.count);
    final totalVertical = _flights.fold<int>(
        0, (sum, f) => sum + (f.verticalMeters ?? 0) * f.count);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Carnet de vol'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'export_csv') _handleExport('csv');
              if (value == 'export_json') _handleExport('json');
              if (value == 'import_file') _handleImportFile();
              if (value == 'import_notes') _handleImportFromNotes();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                  value: 'import_notes',
                  child: Text('Importer depuis Notes (coller)')),
              PopupMenuItem(value: 'import_file', child: Text('Importer un fichier')),
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
                _StatItem(label: 'Dénivelé cumulé', value: '${totalVertical}m'),
                _StatItem(label: 'Sites', value: '${_sites.length}'),
              ],
            ),
          ),
          Expanded(
            child: _flights.isEmpty
                ? const _EmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: _flights.length,
                    itemBuilder: (context, index) {
                      final f = _flights[index];
                      return _FlightRow(
                        entry: f,
                        onTap: () => _openForm(existing: f),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
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
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.paragliding_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text('Aucun vol enregistré', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text('Appuie sur + pour ajouter ton premier vol'),
        ],
      ),
    );
  }
}

class _FlightRow extends StatelessWidget {
  final FlightEntry entry;
  final VoidCallback onTap;

  const _FlightRow({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final date = entry.date;
    final dateStr =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
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
                width: 64,
                child: Text(dateStr,
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center),
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
