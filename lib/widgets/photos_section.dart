import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/external_url.dart';
import '../services/photos_link.dart';

/// Opens the photos/videos taken on the flight's date in the Photos app.
/// The media themselves stay in the Photos library; nothing is stored here.
class PhotosSection extends StatelessWidget {
  final DateTime date;

  const PhotosSection({super.key, required this.date});

  void _openShortcut() {
    openExternalUrl(PhotosLink.shortcutUrl(date));
  }

  void _copyDateAndOpenPhotos(BuildContext context) {
    final query = PhotosLink.searchQuery(date);
    // Not awaited: both the clipboard write and the app switch must start
    // inside the tap handler, or iOS Safari refuses them.
    Clipboard.setData(ClipboardData(text: query));
    openExternalUrl(PhotosLink.photosAppUrl);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('« $query » copié : colle-le dans la recherche de Photos'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Photos & vidéos',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            IconButton(
              tooltip: 'Installer le raccourci',
              icon: const Icon(Icons.help_outline),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const _ShortcutSetupDialog(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _openShortcut,
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Voir les photos du jour'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _copyDateAndOpenPhotos(context),
          icon: const Icon(Icons.content_copy),
          label: const Text('Copier la date et ouvrir Photos'),
        ),
      ],
    );
  }
}

class _ShortcutSetupDialog extends StatelessWidget {
  const _ShortcutSetupDialog();

  static const _steps = [
    'Ouvre l\'app Raccourcis et crée un nouveau raccourci nommé exactement '
        '« ${PhotosLink.shortcutName} ».',
    'Ajoute l\'action « Obtenir les dates de l\'entrée » (Get Dates from '
        'Input) avec « Entrée du raccourci ». Accepte la réception de Texte.',
    'Ajoute « Rechercher des photos » (Find Photos) : filtre « Date de prise '
        'de vue » « est » [Dates], trié par date de prise de vue, plus '
        'anciennes en premier.',
    'Ajoute « Coup d\'œil » (Quick Look) sur [Photos].',
    'Teste depuis un vol : « Voir les photos du jour ».',
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Installer le raccourci'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Le bouton « Voir les photos du jour » lance un raccourci iOS '
              'qui affiche les photos et vidéos (iCloud compris) prises à la '
              'date du vol. À installer une seule fois :',
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < _steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('${i + 1}. ${_steps[i]}'),
              ),
            const SizedBox(height: 4),
            Text(
              'Sans le raccourci, utilise « Copier la date et ouvrir Photos ».',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
