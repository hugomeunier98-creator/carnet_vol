import 'package:flutter/material.dart';

import '../services/app_settings.dart';
import '../theme/app_colors.dart';

Widget _sheetTitle(BuildContext context, String title) => Padding(
  padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
  child: Row(
    children: [
      Expanded(
        child: Text(
          title,
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
);

/// Clair / Sombre / Système.
Future<void> showThemeSheet(BuildContext context) {
  final settings = AppSettings.instance;
  const modes = [
    (ThemeMode.light, 'Clair', Icons.light_mode_outlined),
    (ThemeMode.dark, 'Sombre', Icons.dark_mode_outlined),
    (ThemeMode.system, 'Système', Icons.brightness_auto_outlined),
  ];
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sheetTitle(context, 'Thème'),
          for (final (mode, label, icon) in modes)
            ListTile(
              leading: Icon(icon),
              title: Text(label),
              subtitle: mode == ThemeMode.system
                  ? const Text('Suit le réglage du téléphone')
                  : null,
              trailing: settings.themeMode == mode
                  ? Icon(Icons.check, color: AppColors.accentOn(context))
                  : null,
              onTap: () {
                settings.setThemeMode(mode);
                Navigator.pop(context);
              },
            ),
        ],
      ),
    ),
  );
}

/// The accent colours, as round swatches. Choosing one rebuilds the app.
Future<void> showAccentSheet(BuildContext context) {
  final settings = AppSettings.instance;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sheetTitle(context, "Couleur de l'appli"),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 12,
              children: [
                for (final (name, color) in AppColors.choices)
                  SizedBox(
                    width: 96,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.pop(context);
                        settings.setAccent(color);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border:
                                    settings.accent.toARGB32() ==
                                        color.toARGB32()
                                    ? Border.all(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                        width: 3,
                                      )
                                    : null,
                              ),
                              child:
                                  settings.accent.toARGB32() == color.toARGB32()
                                  ? const Icon(Icons.check, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(height: 6),
                            Text(name),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Text(
              "Sur iPhone, la bande en haut de l'écran prend la nouvelle "
              "couleur au prochain lancement de l'app.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
