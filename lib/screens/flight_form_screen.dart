import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/discipline.dart';
import '../models/flight_entry.dart';
import '../utils/date_format.dart';
import '../widgets/discipline_icon.dart';

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

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce vol ?'),
        content: const Text('Cette action est définitive.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              minimumSize: const Size(64, 40),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) Navigator.of(context).pop('delete');
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _dateChips() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final isToday = _isSameDay(_date, today);
    final isYesterday = _isSameDay(_date, yesterday);
    final isOther = !isToday && !isYesterday;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: const Text("Aujourd'hui"),
          selected: isToday,
          onSelected: (_) => setState(() => _date = today),
        ),
        ChoiceChip(
          label: const Text('Hier'),
          selected: isYesterday,
          onSelected: (_) => setState(() => _date = yesterday),
        ),
        ChoiceChip(
          avatar: Icon(Icons.calendar_today_outlined, size: 16,
              color: isOther ? null : Theme.of(context).colorScheme.onSurfaceVariant),
          label: Text(isOther ? formatLongDate(_date) : 'Autre date'),
          selected: isOther,
          onSelected: (_) => _pickDate(),
        ),
      ],
    );
  }

  Widget _countStepper() {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.repeat, color: cs.onSurfaceVariant),
        const SizedBox(width: 12),
        const Expanded(child: Text('Vols identiques')),
        IconButton.filledTonal(
          onPressed: _count > 1 ? () => setState(() => _count--) : null,
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 40,
          child: Text('$_count',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        ),
        IconButton.filledTonal(
          onPressed: () => setState(() => _count++),
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    final accent = _discipline.color;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: accent,
        title: Text(isEditing ? 'Modifier le vol' : 'Nouveau vol'),
        actions: [
          if (isEditing)
            IconButton(
              tooltip: 'Supprimer',
              onPressed: _confirmDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            SegmentedButton<Discipline>(
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: accent.withValues(alpha: 0.15),
                selectedForegroundColor: _discipline.on(context),
                minimumSize: const Size(0, 46),
              ),
              segments: [
                for (final d in Discipline.values)
                  ButtonSegment(value: d, label: Text(d.label), icon: DisciplineIcon(d, size: 18)),
              ],
              selected: {_discipline},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _discipline = s.single),
            ),
            _FormSection(title: 'Quand', children: [_dateChips()]),
            _FormSection(title: 'Où', children: [
              _autocompleteField(
                label: _discipline == Discipline.parapente ? 'Site / déco' : 'Site',
                icon: Icons.place_outlined,
                controller: _siteController,
                options: widget.knownSites,
                required: true,
              ),
              _autocompleteField(
                label: 'Run (optionnel)',
                icon: Icons.route_outlined,
                controller: _runController,
                options: widget.knownRuns,
              ),
            ]),
            _FormSection(title: 'Vol', children: [
              _autocompleteField(
                // Keyed so the suggestions follow a change of discipline.
                key: ValueKey(_discipline),
                label: 'Voile',
                icon: Icons.paragliding_outlined,
                controller: _wingController,
                options: widget.knownWings[_discipline] ?? const [],
                required: true,
              ),
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
              _countStepper(),
            ]),
            _FormSection(title: 'Notes', children: [
              TextFormField(
                controller: _commentController,
                maxLines: 4,
                minLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Conditions, sensations, à retenir…',
                ),
              ),
            ]),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white),
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: const Text('Enregistrer'),
          ),
        ),
      ),
    );
  }
}

/// A titled group of fields.
class _FormSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _FormSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 20, 6, 8),
          child: Text(title,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  children[i],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
