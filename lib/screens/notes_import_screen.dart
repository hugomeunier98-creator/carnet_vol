import 'package:flutter/material.dart';

import '../models/flight_entry.dart';
import '../services/export_service.dart';

class NotesImportScreen extends StatefulWidget {
  const NotesImportScreen({super.key});

  @override
  State<NotesImportScreen> createState() => _NotesImportScreenState();
}

class _NotesImportScreenState extends State<NotesImportScreen> {
  final _controller = TextEditingController();
  final _export = ExportService();
  List<FlightEntry>? _preview;

  void _parse() {
    setState(() => _preview = _export.parseNotesTable(_controller.text));
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    return Scaffold(
      appBar: AppBar(title: const Text('Importer depuis Notes')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Colle ici le tableau copié depuis ta note iCloud "
              '(colonnes : Nº, Date, Lieu, Run, Dénivelé/Durée, Voile).',
            ),
            const SizedBox(height: 12),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Colle le tableau ici…',
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _parse,
              icon: const Icon(Icons.search),
              label: const Text('Analyser'),
            ),
            const SizedBox(height: 12),
            if (preview != null) ...[
              Text('${preview.length} vol(s) détecté(s)',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Expanded(
                flex: 3,
                child: preview.isEmpty
                    ? const Center(child: Text('Aucune ligne reconnue.'))
                    : ListView.builder(
                        itemCount: preview.length,
                        itemBuilder: (context, index) {
                          final f = preview[index];
                          final d =
                              '${f.date.day.toString().padLeft(2, '0')}/${f.date.month.toString().padLeft(2, '0')}/${f.date.year}';
                          return ListTile(
                            dense: true,
                            leading: Text(f.sourceNumber ?? '',
                                style: Theme.of(context).textTheme.bodySmall),
                            title: Text('$d · ${f.site}'
                                '${f.run.isNotEmpty ? ' · ${f.run}' : ''}'),
                            subtitle: Text(
                                '${f.wing} · ${f.verticalOrDuration}${f.count > 1 ? ' · ×${f.count}' : ''}'),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: preview.isEmpty
                    ? null
                    : () => Navigator.of(context).pop(preview),
                icon: const Icon(Icons.check),
                label: Text('Importer ces ${preview.length} vol(s)'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
