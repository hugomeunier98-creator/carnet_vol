class FlightEntry {
  final String id;
  final DateTime date;
  final String site;
  final String run;
  final String verticalOrDuration;
  final String wing;
  final int count;
  final String comment;
  final String? sourceNumber;

  const FlightEntry({
    required this.id,
    required this.date,
    required this.site,
    this.run = '',
    this.verticalOrDuration = '',
    required this.wing,
    this.count = 1,
    this.comment = '',
    this.sourceNumber,
  });

  /// Vertical drop in meters, parsed from [verticalOrDuration] when it starts
  /// with a plain number (e.g. "800" or "600/soaring"). Null when the field
  /// holds a duration instead (e.g. "1h", "soaring").
  int? get verticalMeters {
    final numPart = verticalOrDuration.split('/').first.trim();
    if (RegExp(r'^\d+$').hasMatch(numPart)) return int.parse(numPart);
    return null;
  }

  /// Display label for the flight counter, e.g. "212" or "212-213" when this
  /// entry groups several identical flights. [sourceNumber] always holds the
  /// starting flight number as a plain integer string.
  String? get flightNumberLabel {
    final start = int.tryParse(sourceNumber ?? '');
    if (start == null) return null;
    return count > 1 ? '$start-${start + count - 1}' : '$start';
  }

  FlightEntry copyWith({
    DateTime? date,
    String? site,
    String? run,
    String? verticalOrDuration,
    String? wing,
    int? count,
    String? comment,
    String? sourceNumber,
  }) {
    return FlightEntry(
      id: id,
      date: date ?? this.date,
      site: site ?? this.site,
      run: run ?? this.run,
      verticalOrDuration: verticalOrDuration ?? this.verticalOrDuration,
      wing: wing ?? this.wing,
      count: count ?? this.count,
      comment: comment ?? this.comment,
      sourceNumber: sourceNumber ?? this.sourceNumber,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'site': site,
        'run': run,
        'verticalOrDuration': verticalOrDuration,
        'wing': wing,
        'count': count,
        'comment': comment,
        'sourceNumber': sourceNumber,
      };

  factory FlightEntry.fromJson(Map<String, dynamic> json) => FlightEntry(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String),
        site: json['site'] as String,
        run: (json['run'] as String?) ?? '',
        verticalOrDuration: (json['verticalOrDuration'] as String?) ?? '',
        wing: json['wing'] as String,
        count: (json['count'] as int?) ?? 1,
        comment: (json['comment'] as String?) ?? '',
        sourceNumber: json['sourceNumber'] as String?,
      );
}
