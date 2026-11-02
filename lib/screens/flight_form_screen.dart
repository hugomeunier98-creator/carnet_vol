import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/discipline.dart';
import '../models/flight_entry.dart';

class FlightFormScreen extends StatefulWidget {
  final FlightEntry? existing;

  /// Discipline of a new flight; an edited flight starts on its own.
  final Discipline discipline;
  final List<String> knownSites;
  final List<String> knownRuns;

  /// Wing suggestions, per discipline.
  final Map<Discipline, List<String>> knownWings;

  const FlightFormScreen({
    super.key,
    this.existing,
    this.discipline = Discipline.speedflying,
    required this.knownSites,
    required this.knownRuns,
    required this.knownWings,
  });

  @override
  State<FlightFormScreen> createState() => _FlightFormScreenState();
}

class _FlightFormScreenState extends State<FlightFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _date;
  late Discipline _discipline;
  late TextEditingController _siteController;
  late TextEditingController _runController;
  late TextEditingController _verticalController;
  late TextEditingController _wingController;
  late TextEditingController _commentController;
  int _count = 1;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _date = e?.date ?? DateTime.now();
    _discipline = e?.discipline ?? widget.discipline;
    _siteController = TextEditingController(text: e?.site ?? '');
    _runController = TextEditingController(text: e?.run ?? '');
    _verticalController = TextEditingController(text: e?.verticalOrDuration ?? '');
    _wingController = TextEditingController(text: e?.wing ?? '');
    _commentController = TextEditingController(text: e?.comment ?? '');
    _count = e?.count ?? 1;
  }

  @override
  void dispose() {
    _siteController.dispose();
    _runController.dispose();
    _verticalController.dispose();
    _wingController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final entry = FlightEntry(
      id: widget.existing?.id ?? const Uuid().v4(),
      discipline: _discipline,
      date: _date,
      site: _siteController.text.trim(),
      run: _runController.text.trim(),
      verticalOrDuration: _verticalController.text.trim(),
      wing: _wingController.text.trim(),
      count: _count,
      comment: _commentController.text.trim(),
      sourceNumber: widget.existing?.sourceNumber,
    );
    Navigator.of(context).pop(entry);
  }

  Widget _autocompleteField({
    Key? key,
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required List<String> options,
    bool required = false,
  }) {
    return Autocomplete<String>(
      key: key,
      optionsBuilder: (v) {
        if (v.text.isEmpty) return options;
        return options.where((s) => s.toLowerCase().contains(v.text.toLowerCase()));
      },
      initialValue: TextEditingValue(text: controller.text),
      onSelected: (v) => controller.text = v,
      fieldViewBuilder: (context, fieldController, focusNode, onSubmit) {
        fieldController.text = controller.text;
        fieldController.addListener(() => controller.text = fieldController.text);
        return TextFormField(
          controller: fieldController,
          focusNode: focusNode,
          decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
          validator: required
              ? (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null
              : null,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Modifier le vol' : 'Nouveau vol')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<Discipline>(
              segments: [
                for (final d in Discipline.values)
                  ButtonSegment(value: d, label: Text(d.label), icon: Icon(d.icon)),
              ],
              selected: {_discipline},
              onSelectionChanged: (s) => setState(() => _discipline = s.single),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                  '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}',
                ),
              ),
            ),
            const SizedBox(height: 16),
            _autocompleteField(
              label: 'Lieu / site de vol',
              icon: Icons.place_outlined,
              controller: _siteController,
              options: widget.knownSites,
              required: true,
            ),
            const SizedBox(height: 16),
            _autocompleteField(
              label: 'Run (optionnel)',
              icon: Icons.route_outlined,
              controller: _runController,
              options: widget.knownRuns,
            ),
            const SizedBox(height: 16),
            _autocompleteField(
              // Keyed so the suggestions follow a change of discipline.
              key: ValueKey(_discipline),
              label: 'Voile',
              icon: Icons.paragliding_outlined,
              controller: _wingController,
              options: widget.knownWings[_discipline] ?? const [],
              required: true,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _verticalController,
              // Speedflying logs mostly vertical drop; parapente a duration.
              decoration: _discipline == Discipline.parapente
                  ? const InputDecoration(
                      labelText: 'Durée',
                      helperText: 'ex: 45min, 1h30',
                      prefixIcon: Icon(Icons.timer_outlined),
                    )
                  : const InputDecoration(
                      labelText: 'Dénivelé / durée',
                      helperText: 'ex: 800, 1h, soaring, 600/soaring',
                      prefixIcon: Icon(Icons.trending_down),
                    ),
            ),
            const SizedBox(height: 16),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Nombre de vols identiques',
                prefixIcon: Icon(Icons.repeat),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$_count', style: Theme.of(context).textTheme.titleMedium),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _count > 1 ? () => setState(() => _count--) : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      IconButton(
                        onPressed: () => setState(() => _count++),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _commentController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Commentaire',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: const Text('Enregistrer'),
            ),
            if (isEditing) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop('delete'),
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: const Text('Supprimer', style: TextStyle(color: Colors.red)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
