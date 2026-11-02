import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/external_url.dart';
import '../services/photos_link.dart';

/// Opens the Photos app with the flight's date copied, ready to paste into
/// the Photos search. The media themselves stay in the Photos library.
class PhotosSection extends StatelessWidget {
  final DateTime date;

  const PhotosSection({super.key, required this.date});

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
        Text('Photos & vidéos', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () => _copyDateAndOpenPhotos(context),
          icon: const Icon(Icons.photo_library_outlined),
          label: Text('Copier ${PhotosLink.searchQuery(date)} et ouvrir Photos'),
        ),
      ],
    );
  }
}
