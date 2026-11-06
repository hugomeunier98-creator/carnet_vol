import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Shares [text] through the phone's share sheet (WhatsApp, Messages…).
/// Must run straight from a tap: iOS refuses to share otherwise.
Future<void> shareText(String text, {String? subject}) =>
    SharePlus.instance.share(ShareParams(text: text, subject: subject));

/// Shows the message about to be shared, with "Partager" and "Copier".
/// Used from menus, whose tap is over by the time an item runs.
Future<void> showShareSiteSheet(BuildContext context, String text) {
  final cs = Theme.of(context).colorScheme;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Partager le site',
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
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: SelectableText(text),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: text));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Message copié')),
                    );
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copier'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    shareText(text);
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.ios_share),
                  label: const Text('Partager'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
