import 'package:web/web.dart' as web;

/// Navigates the current page to [url]. For app schemes (shortcuts://,
/// photos-redirect://) iOS hands the URL to the target app and the PWA stays
/// where it was; a new window would instead bounce through Safari.
void openExternalUrl(String url) {
  web.window.location.href = url;
}
