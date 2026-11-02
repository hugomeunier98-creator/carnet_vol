import 'dart:js_interop';

// Defined in web/index.html.
@JS('carnetVolBuildId')
external String get _buildId;

@JS('carnetVolFetchLatestBuild')
external JSPromise<JSString?> _fetchLatestBuild();

@JS('carnetVolApplyUpdate')
external JSPromise<JSAny?> _applyUpdate();

/// Compares this build with the one live on GitHub Pages and reloads into
/// the new one, bypassing the browser cache.
class AppUpdate {
  /// Build id stamped by scripts/deploy.sh; null for an unstamped dev build.
  static String? get currentBuild =>
      _buildId.startsWith('__') ? null : _buildId;

  /// Live build id, or null when it can't be checked (offline, dev build).
  static Future<String?> latestBuild() async =>
      (await _fetchLatestBuild().toDart)?.toDart;

  /// Downloads the live build and reloads the page.
  static Future<void> apply() => _applyUpdate().toDart;
}
