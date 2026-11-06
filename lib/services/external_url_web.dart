import 'package:web/web.dart' as web;

/// Opens [url]. For app links (photos-redirect://, Android intents) the
/// current page navigates to it: the system hands it to the target app and
/// the PWA stays where it was; a new window would instead bounce through
/// the browser. A website ([newTab]) opens beside the app.
void openExternalUrl(String url, {bool newTab = false}) {
  if (newTab) {
    web.window.open(url, '_blank');
  } else {
    web.window.location.href = url;
  }
}
