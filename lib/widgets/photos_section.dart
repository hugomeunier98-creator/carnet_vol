import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/external_url.dart';
import '../services/photos_link.dart';

/// Opens the phone's photo app (Photos on iPhone, Google Photos elsewhere)
/// with the flight's date copied, ready to paste into its search. The
/// media themselves stay in the photo library.
class PhotosSection extends StatelessWidget {
  final DateTime date;

  const PhotosSection({super.key, required this.date});

  void _copyDateAndOpenPhotos(BuildContext context, PhotosLink link) {
    // Not awaited: both the clipboard write and the app switch must start
    // inside the tap handler, or iOS Safari refuses them.
    Clipboard.setData(ClipboardData(text: link.query));
    openExternalUrl(link.url, newTab: !link.opensApp);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '« ${link.query} » copié : colle-le dans la recherche de '
          '${link.appName} si besoin',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final link = PhotosLink.forDate(date);
    return FilledButton.tonalIcon(
      onPressed: () => _copyDateAndOpenPhotos(context, link),
      icon: const Icon(Icons.photo_library_outlined),
      label: Text('Copier date et ouvrir ${link.appName}'),
    );
  }
}
