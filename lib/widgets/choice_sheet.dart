import 'package:flutter/material.dart';

import 'clear_button.dart';

/// Lets the user pick one of [options] in a sheet that rises from the
/// bottom of the screen: full width, with a search field when the list is
/// long, closed by its cross, a swipe down or a tap above it.
///
/// [allLabel] adds a first entry meaning "no choice" (e.g. "Tous" in the
/// filters); picking it returns ''. With [allowNew], what is typed in the
/// search can be used as a new value. Null when the sheet is closed
/// without a choice.
Future<String?> showChoiceSheet(
  BuildContext context, {
  required String title,
  required List<String> options,
  String? selected,
  String? allLabel,
  bool allowNew = false,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _ChoiceSheet(
      title: title,
      options: options,
      selected: selected,
      allLabel: allLabel,
      allowNew: allowNew,
    ),
  );
}

class _ChoiceSheet extends StatefulWidget {
  final String title;
  final List<String> options;
  final String? selected;
  final String? allLabel;
  final bool allowNew;

  const _ChoiceSheet({
    required this.title,
    required this.options,
    required this.selected,
    required this.allLabel,
    required this.allowNew,
  });

  @override
  State<_ChoiceSheet> createState() => _ChoiceSheetState();
}

class _ChoiceSheetState extends State<_ChoiceSheet> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _searchable => widget.allowNew || widget.options.length > 6;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final query = _search.text.trim();
    final lower = query.toLowerCase();
    final shown = lower.isEmpty
        ? widget.options
        : widget.options.where((o) => o.toLowerCase().contains(lower)).toList();
    final canAdd =
        widget.allowNew &&
        query.isNotEmpty &&
        !widget.options.any((o) => o.toLowerCase() == lower);

    Widget option(String label, String value, {bool isSelected = false}) =>
        ListTile(
          title: Text(
            label,
            style: isSelected
                ? TextStyle(color: cs.primary, fontWeight: FontWeight.w700)
                : null,
          ),
          trailing: isSelected ? Icon(Icons.check, color: cs.primary) : null,
          onTap: () => Navigator.pop(context, value),
        );

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fermer',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            if (_searchable)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: TextField(
                  controller: _search,
                  autofocus: widget.allowNew,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: widget.allowNew
                        ? 'Rechercher ou saisir un nom'
                        : 'Rechercher',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: ClearButton(_search),
                  ),
                  onSubmitted: (_) {
                    if (canAdd) {
                      Navigator.pop(context, query);
                    } else if (shown.length == 1) {
                      Navigator.pop(context, shown.single);
                    }
                  },
                ),
              ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  if (widget.allLabel != null && lower.isEmpty)
                    option(
                      widget.allLabel!,
                      '',
                      isSelected: widget.selected == null,
                    ),
                  for (final o in shown)
                    option(o, o, isSelected: o == widget.selected),
                  if (canAdd)
                    ListTile(
                      leading: Icon(Icons.add, color: cs.primary),
                      title: Text(
                        'Nouveau : « $query »',
                        style: TextStyle(
                          color: cs.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onTap: () => Navigator.pop(context, query),
                    ),
                  if (shown.isEmpty && !canAdd)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Aucun résultat',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A form field whose value is picked with [showChoiceSheet] (a new name
/// can be typed there too). Tapping the field opens the sheet; the cross
/// empties it.
class ChoiceFormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final List<String> options;
  final bool required;

  const ChoiceFormField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    required this.options,
    this.required = false,
  });

  Future<void> _pick(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final picked = await showChoiceSheet(
      context,
      title: label,
      options: options,
      selected: controller.text.isEmpty ? null : controller.text,
      allowNew: true,
    );
    if (picked != null && picked.isNotEmpty) controller.text = picked;
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: () => _pick(context),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => value.text.isEmpty
              ? const Icon(Icons.expand_more)
              : ClearButton(controller),
        ),
      ),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null
          : null,
    );
  }
}

/// A read-only field showing a choice made with [showChoiceSheet], for
/// filters: [allLabel] when nothing is chosen, a cross to go back to it.
class ChoiceFilterField extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> options;
  final String allLabel;
  final ValueChanged<String?> onChanged;

  const ChoiceFilterField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.allLabel = 'Tous',
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final picked = await showChoiceSheet(
          context,
          title: label,
          options: options,
          selected: value,
          allLabel: allLabel,
        );
        if (picked != null) onChanged(picked.isEmpty ? null : picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: value == null
              ? const Icon(Icons.expand_more)
              : IconButton(
                  tooltip: 'Effacer',
                  icon: const Icon(Icons.cancel, size: 20),
                  onPressed: () => onChanged(null),
                ),
        ),
        child: Text(value ?? allLabel, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
