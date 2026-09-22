import 'package:flutter/material.dart';

import '../models/flight_entry.dart';
import '../services/blob_opener.dart';
import '../services/media_service.dart';
import '../utils/progress_eta.dart';

class MediaImportScreen extends StatefulWidget {
  final List<FlightEntry> flights;

  const MediaImportScreen({super.key, required this.flights});

  @override
  State<MediaImportScreen> createState() => _MediaImportScreenState();
}

class _PendingAssignment {
  final PendingMedia pending;
  List<FlightEntry> candidates;
  FlightEntry? selected;
  bool skip;

  _PendingAssignment({required this.pending, required this.candidates, this.selected})
      : skip = candidates.isEmpty;
}

class _MediaImportScreenState extends State<MediaImportScreen> {
  final _mediaService = MediaService();
  List<_PendingAssignment> _assignments = [];
  bool _busy = false;
  bool _importing = false;
  int _progress = 0;
  int _total = 0;
  int? _etaSeconds;

  bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _pickAndProcess() async {
    List<dynamic> files;
    try {
      files = await _mediaService.pickFiles();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Impossible d'ouvrir la galerie : $e")));
      }
      return;
    }
    if (files.isEmpty) return;

    setState(() {
      _busy = true;
      _progress = 0;
      _total = files.length;
      _etaSeconds = null;
    });
    final eta = ProgressEta();
    final assignments = <_PendingAssignment>[];
    var skipped = 0;
    for (final file in files) {
      try {
        final pending = await _mediaService.process(file);
        final capturedAt = pending.capturedAt;
        final candidates = capturedAt == null
            ? <FlightEntry>[]
            : widget.flights.where((f) => _sameDate(f.date, capturedAt)).toList();
        assignments.add(_PendingAssignment(
          pending: pending,
          candidates: candidates,
          selected: candidates.length == 1 ? candidates.first : null,
        ));
      } catch (_) {
        skipped++;
      }
      if (mounted) {
        setState(() {
          _progress++;
          _etaSeconds = eta.remainingSeconds(_progress, _total);
        });
      }
      // Yield a frame so the progress bar actually repaints between files -
      // image/video processing runs synchronously and can otherwise freeze
      // the UI for the whole batch.
      await Future<void>.delayed(Duration.zero);
    }
    if (!mounted) return;
    setState(() {
      _assignments = assignments;
      _busy = false;
    });
    if (skipped > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('$skipped fichier(s) ignoré(s) (déjà importé, trop volumineux ou illisible)')),
      );
    }
  }

  void _preview(BuildContext context, _PendingAssignment a) {
    if (a.pending.isVideo) {
      openBytesInNewTab(a.pending.bytes, a.pending.mimeType);
      return;
    }
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: InteractiveViewer(child: Image.memory(a.pending.bytes)),
      ),
    );
  }

  String _flightLabel(FlightEntry f) {
    final d = '${f.date.day.toString().padLeft(2, '0')}/${f.date.month.toString().padLeft(2, '0')}/${f.date.year}';
    final loc = f.run.isNotEmpty ? '${f.site} · ${f.run}' : f.site;
    return '$d · $loc (${f.wing})';
  }

  Future<void> _confirmImport() async {
    final toImport = _assignments.where((a) => !a.skip && a.selected != null).toList();
    setState(() {
      _importing = true;
      _progress = 0;
      _total = toImport.length;
      _etaSeconds = null;
    });
    final eta = ProgressEta();
    var imported = 0;
    for (final a in toImport) {
      await _mediaService.saveForFlight(a.pending, a.selected!.id);
      imported++;
      if (mounted) {
        setState(() {
          _progress++;
          _etaSeconds = eta.remainingSeconds(_progress, _total);
        });
      }
    }
    if (!mounted) return;
    Navigator.of(context).pop(imported);
  }

  @override
  Widget build(BuildContext context) {
    final autoMatched = _assignments.where((a) => !a.skip && a.candidates.length == 1).length;
    final needsChoice = _assignments.where((a) => !a.skip && a.candidates.length > 1).length;
    final unmatched = _assignments.where((a) => a.candidates.isEmpty).length;
    final readyToImport = _assignments.any((a) => !a.skip && a.selected != null);

    return Scaffold(
      appBar: AppBar(title: const Text('Importer des médias')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "Sélectionne en une fois toutes les photos/vidéos d'une sortie : "
                  'chaque fichier sera associé automatiquement au vol de la même date, '
                  'ou proposé pour confirmation si plusieurs vols partagent ce jour-là.',
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy ? null : _pickAndProcess,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.photo_library_outlined),
                  label: Text(_busy ? 'Analyse $_progress/$_total…' : 'Choisir des photos/vidéos'),
                ),
                if (_busy) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _total > 0 ? _progress / _total : null,
                      minHeight: 4,
                    ),
                  ),
                  if (formatEta(_etaSeconds).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(formatEta(_etaSeconds),
                          style: Theme.of(context).textTheme.bodySmall),
                    ),
                ],
                if (_assignments.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    '$autoMatched associé(s) automatiquement · '
                    '$needsChoice à confirmer · '
                    '$unmatched non associé(s)',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _assignments.length,
              itemBuilder: (context, index) {
                final a = _assignments[index];
                final allOptions = a.candidates.isNotEmpty ? a.candidates : widget.flights;
                return Opacity(
                  opacity: a.skip ? 0.5 : 1,
                  child: ListTile(
                    leading: GestureDetector(
                      onTap: () => _preview(context, a),
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: a.pending.isVideo
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  color: Colors.black87,
                                  child: const Center(
                                    child: Icon(Icons.play_circle_outline,
                                        color: Colors.white, size: 26),
                                  ),
                                ),
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.memory(a.pending.bytes, fit: BoxFit.cover),
                              ),
                      ),
                    ),
                    title: Text(a.pending.fileName, overflow: TextOverflow.ellipsis),
                    subtitle: DropdownButton<FlightEntry>(
                      isExpanded: true,
                      value: a.selected,
                      hint: Text(a.candidates.isEmpty
                          ? 'Aucun vol ce jour — choisir manuellement'
                          : 'Choisir un vol'),
                      items: allOptions
                          .map((f) => DropdownMenuItem(value: f, child: Text(_flightLabel(f))))
                          .toList(),
                      onChanged: a.skip
                          ? null
                          : (f) => setState(() => a.selected = f),
                    ),
                    trailing: IconButton(
                      icon: Icon(a.skip ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                      tooltip: a.skip ? 'Réactiver' : 'Ignorer',
                      onPressed: () => setState(() => a.skip = !a.skip),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_assignments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_importing) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _total > 0 ? _progress / _total : null,
                        minHeight: 4,
                      ),
                    ),
                    if (formatEta(_etaSeconds).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(formatEta(_etaSeconds),
                            style: Theme.of(context).textTheme.bodySmall),
                      ),
                    const SizedBox(height: 8),
                  ],
                  FilledButton.icon(
                    onPressed: (!readyToImport || _importing) ? null : _confirmImport,
                    icon: _importing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.check),
                    label: Text(_importing ? 'Import $_progress/$_total…' : 'Importer'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
