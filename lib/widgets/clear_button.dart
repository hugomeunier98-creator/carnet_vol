import 'package:flutter/material.dart';

/// A small cross at the end of a text field that empties it in one tap.
/// Hidden while the field is empty. Use as the field's suffixIcon.
class ClearButton extends StatelessWidget {
  final TextEditingController controller;

  const ClearButton(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => value.text.isEmpty
          ? const SizedBox.shrink()
          : IconButton(
              icon: const Icon(Icons.cancel, size: 20),
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              tooltip: 'Effacer',
              onPressed: controller.clear,
            ),
    );
  }
}
