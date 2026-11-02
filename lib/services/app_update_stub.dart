/// Outside the web there is no deployed build to compare against.
class AppUpdate {
  static String? get currentBuild => null;

  static Future<String?> latestBuild() async => null;

  static Future<void> apply() async {}
}
