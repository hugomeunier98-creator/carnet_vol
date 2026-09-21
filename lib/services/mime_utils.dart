const _imageExtensions = {
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'heic': 'image/heic',
  'webp': 'image/webp',
  'gif': 'image/gif',
};

const _videoExtensions = {
  'mp4': 'video/mp4',
  'mov': 'video/quicktime',
  'm4v': 'video/x-m4v',
  'webm': 'video/webm',
};

String guessMimeType(String fileName) {
  final ext = fileName.toLowerCase().split('.').last;
  return _imageExtensions[ext] ?? _videoExtensions[ext] ?? 'application/octet-stream';
}

bool mimeIsVideo(String mimeType) => mimeType.startsWith('video/');
