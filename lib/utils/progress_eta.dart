/// Estimates remaining time for a batch of items being processed one by
/// one, based on the average pace observed so far.
class ProgressEta {
  final DateTime _start = DateTime.now();

  int? remainingSeconds(int done, int total) {
    if (done <= 0 || total <= 0 || done >= total) return null;
    final elapsedMs = DateTime.now().difference(_start).inMilliseconds;
    final perItemMs = elapsedMs / done;
    final remainingMs = (total - done) * perItemMs;
    return (remainingMs / 1000).round();
  }
}

String formatEta(int? seconds) {
  if (seconds == null || seconds <= 0) return '';
  if (seconds < 60) return '≈${seconds}s restantes';
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '≈$m min ${s.toString().padLeft(2, '0')} restantes';
}
