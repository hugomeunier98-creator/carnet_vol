import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

void openBytesInNewTab(Uint8List bytes, String mimeType) {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  web.window.open(url, '_blank');
}
