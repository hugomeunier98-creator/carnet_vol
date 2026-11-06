import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/external_url.dart';
import '../services/photos_link.dart';

/// Copies the flight's date for the search of the photo app, and on iPhone
/// opens Photos. The media themselves stay in the photo library.
class PhotosSection extends StatelessWidget {
  final DateTime date;

  const PhotosSection({super.key, required this.date});

  void _copyDate(BuildContext context, PhotosLink link) {
    final query = PhotosLink.searchQuery(date);
    // Not awaited: both the clipboard write and the app switch must start
    // inside the tap handler, or iOS Safari refuses them.
    Clipboard.setData(ClipboardData(text: query));
    final url = link.url;
    if (url != null) openExternalUrl(url);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          url != null
              ? '« $query » copié : colle-le dans la recherche de Photos'
              : "Date du vol copiée à coller dans l'onglet recherche de "
                    "l'application Photos",
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final link = PhotosLink.forDevice();
    return FilledButton.tonalIcon(
      onPressed: () => _copyDate(context, link),
      icon: const Icon(Icons.photo_library_outlined),
      label: Text(
        link.url != null ? 'Copier date et ouvrir Photos' : 'Ouvrir Photos',
      ),
    );
  }
}
