import 'discipline.dart';

class FlightEntry {
  final String id;
  final Discipline discipline;
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
    this.discipline = Discipline.speedflying,
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

  /// Display label for the flight counter, e.g. "#212" or "#212 - #213" when
  /// this entry groups several identical flights. [sourceNumber] always
  /// holds the starting flight number as a plain integer string.
  String? get flightNumberLabel {
    final start = int.tryParse(sourceNumber ?? '');
    if (start == null) return null;
    return count > 1 ? '#$start - #${start + count - 1}' : '#$start';
  }

  FlightEntry copyWith({
    Discipline? discipline,
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
      discipline: discipline ?? this.discipline,
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

  /// Parapente has no runs (a run is a speedflying line; the site is the
  /// takeoff or flying area): a run imported or kept from before for a
  /// parapente flight moves to the comment.
  FlightEntry withoutParapenteRun() {
    if (discipline != Discipline.parapente || run.isEmpty) return this;
    return copyWith(
      run: '',
      comment: comment.isEmpty ? run : '$comment · $run',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'discipline': discipline.name,
    'date': date.toIso8601String(),
    'site': site,
    'run': run,
    'verticalOrDuration': verticalOrDuration,
    'wing': wing,
    'count': count,
    'comment': comment,
    'sourceNumber': sourceNumber,
  };

  /// [fallbackDiscipline] applies when the JSON has no discipline (data
  /// saved or exported before disciplines existed).
  factory FlightEntry.fromJson(
    Map<String, dynamic> json, {
    Discipline fallbackDiscipline = Discipline.speedflying,
  }) => FlightEntry(
    id: json['id'] as String,
    discipline:
        Discipline.tryParse(json['discipline'] as String?) ??
        fallbackDiscipline,
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
