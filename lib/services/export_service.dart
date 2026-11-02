import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:uuid/uuid.dart';

import '../models/discipline.dart';
import '../models/flight_entry.dart';

class ExportService {
  String toJson(List<FlightEntry> flights) {
    final list = flights.map((f) => f.toJson()).toList();
    return const JsonEncoder.withIndent('  ').convert(list);
  }

  String toCsv(List<FlightEntry> flights) {
    final buffer = StringBuffer();
    buffer.writeln('numero,date,site,run,denivele_duree,voile,nb_vols,commentaire,discipline');
    for (final f in flights) {
      buffer.writeln([
        f.sourceNumber ?? '',
        f.date.toIso8601String().split('T').first,
        _escape(f.site),
        _escape(f.run),
        _escape(f.verticalOrDuration),
        _escape(f.wing),
        f.count,
        _escape(f.comment),
        f.discipline.name,
      ].join(','));
    }
    return buffer.toString();
  }

  String _escape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  Future<void> exportToFile(String content, String suggestedName) async {
    final location = await getSaveLocation(suggestedName: suggestedName);
    if (location == null) return;
    final bytes = Uint8List.fromList(utf8.encode(content));
    final file = XFile.fromData(bytes, mimeType: 'text/plain');
    await file.saveTo(location.path);
  }

  /// Flights without a discipline in the file get [fallbackDiscipline].
  Future<List<FlightEntry>?> importFromFile(Discipline fallbackDiscipline) async {
    const jsonType = XTypeGroup(label: 'JSON', extensions: ['json']);
    const csvType = XTypeGroup(label: 'CSV', extensions: ['csv']);
    final file = await openFile(acceptedTypeGroups: [jsonType, csvType]);
    if (file == null) return null;
    final content = await file.readAsString();
    if (file.name.toLowerCase().endsWith('.csv')) {
      return parseCsv(content, fallbackDiscipline);
    }
    return _parseJson(content, fallbackDiscipline);
  }

  List<FlightEntry> _parseJson(String content, Discipline fallbackDiscipline) {
    final list = jsonDecode(content) as List<dynamic>;
    return list
        .map((e) => FlightEntry.fromJson(e as Map<String, dynamic>,
            fallbackDiscipline: fallbackDiscipline))
        .toList();
  }

  List<FlightEntry> parseCsv(String content, Discipline fallbackDiscipline) {
    final lines = const LineSplitter()
        .convert(content)
        .where((l) => l.trim().isNotEmpty)
        .toList();
    if (lines.isEmpty) return [];
    final result = <FlightEntry>[];
    for (final line in lines.skip(1)) {
      final fields = _splitCsvLine(line);
      if (fields.length < 6) continue;
      result.add(FlightEntry(
        id: const Uuid().v4(),
        sourceNumber: fields[0].isEmpty ? null : fields[0],
        date: DateTime.parse(fields[1]),
        site: fields[2],
        run: fields[3],
        verticalOrDuration: fields[4],
        wing: fields[5],
        count: fields.length > 6 ? (int.tryParse(fields[6]) ?? 1) : 1,
        comment: fields.length > 7 ? fields[7] : '',
        discipline: (fields.length > 8 ? Discipline.tryParse(fields[8]) : null) ??
            fallbackDiscipline,
      ));
    }
    return result;
  }

  List<String> _splitCsvLine(String line) {
    final fields = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (inQuotes) {
        if (char == '"') {
          if (i + 1 < line.length && line[i + 1] == '"') {
            buffer.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          buffer.write(char);
        }
      } else {
        if (char == '"') {
          inQuotes = true;
        } else if (char == ',') {
          fields.add(buffer.toString());
          buffer.clear();
        } else {
          buffer.write(char);
        }
      }
    }
    fields.add(buffer.toString());
    return fields;
  }

  /// Column layout of a pasted Notes table when it has no recognisable
  /// header row: the speedflying note is `Nº · Date · Lieu · Run ·
  /// Dénivelé/Durée · Voile`, the parapente one `Nº · Date · Déco · Durée ·
  /// Voile`.
  static Map<_NotesColumn, int> _defaultColumns(Discipline discipline) =>
      switch (discipline) {
        Discipline.speedflying => {
            _NotesColumn.date: 1,
            _NotesColumn.site: 2,
            _NotesColumn.run: 3,
            _NotesColumn.verticalOrDuration: 4,
            _NotesColumn.wing: 5,
          },
        Discipline.parapente => {
            _NotesColumn.date: 1,
            _NotesColumn.site: 2,
            _NotesColumn.verticalOrDuration: 3,
            _NotesColumn.wing: 4,
          },
      };

  /// Reads a header row ("Nº  Date  Déco  Durée  Voile"...) into column
  /// positions; null when the line isn't a header (no "Date" column).
  static Map<_NotesColumn, int>? _headerColumns(List<String> fields) {
    String normalize(String s) => s
        .toLowerCase()
        .replaceAll(RegExp('[éèêë]'), 'e')
        .replaceAll(RegExp('[àâä]'), 'a')
        .replaceAll(RegExp('[ùûü]'), 'u')
        .replaceAll(RegExp('[îï]'), 'i')
        .replaceAll(RegExp('[ôö]'), 'o');
    final columns = <_NotesColumn, int>{};
    for (var i = 1; i < fields.length; i++) {
      final name = normalize(fields[i]);
      final column = name.contains('date')
          ? _NotesColumn.date
          : name.contains('voile')
              ? _NotesColumn.wing
              : name.contains('denivele') || name.contains('duree')
                  ? _NotesColumn.verticalOrDuration
                  : name.contains('lieu') || name.contains('site') || name.contains('deco')
                      ? _NotesColumn.site
                      : name.contains('run')
                          ? _NotesColumn.run
                          : name.contains('comment') || name.contains('remarque')
                              ? _NotesColumn.comment
                              : null;
      if (column != null) columns.putIfAbsent(column, () => i);
    }
    return columns.containsKey(_NotesColumn.date) ? columns : null;
  }

  /// Parses a table pasted from Apple Notes (tab-separated columns). The
  /// first column is the flight number and may hold a range ("6-8" = 3
  /// grouped identical flights); the date may be left blank to mean "same
  /// date as the row above". Other columns are found by their header (Lieu
  /// or Déco, Run, Dénivelé or Durée, Voile, Commentaire), falling back to
  /// the [discipline]'s usual layout when the header wasn't pasted.
  List<FlightEntry> parseNotesTable(String raw, Discipline discipline) {
    final result = <FlightEntry>[];
    DateTime? lastDate;
    const uuid = Uuid();
    final numberPattern = RegExp(r'^\d+(-\d+)?$');
    final datePattern = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{2}|\d{4})$');
    var columns = _defaultColumns(discipline);

    for (final rawLine in raw.split('\n')) {
      final line = rawLine.trimRight();
      if (line.trim().isEmpty) continue;
      final fields = line.split('\t').map((f) => f.trim()).toList();
      if (fields.isEmpty) continue;

      final noField = fields[0];
      if (!numberPattern.hasMatch(noField)) {
        // Header or title line.
        columns = _headerColumns(fields) ?? columns;
        continue;
      }
      String field(_NotesColumn column) {
        final i = columns[column];
        return i != null && i < fields.length ? fields[i] : '';
      }

      var count = 1;
      var startNumber = int.tryParse(noField);
      if (noField.contains('-')) {
        final parts = noField.split('-');
        final start = int.tryParse(parts[0]);
        final end = int.tryParse(parts[1]);
        if (start != null && end != null && end >= start) {
          count = end - start + 1;
          startNumber = start;
        }
      }

      final dateField = field(_NotesColumn.date);
      DateTime? date = lastDate;
      final match = datePattern.firstMatch(dateField);
      if (match != null) {
        final day = int.parse(match.group(1)!);
        final month = int.parse(match.group(2)!);
        var year = int.parse(match.group(3)!);
        if (year < 100) year += 2000;
        date = DateTime(year, month, day);
      }
      if (date == null) continue; // no date available yet, skip row
      lastDate = date;

      result.add(FlightEntry(
        id: uuid.v4(),
        discipline: discipline,
        date: date,
        site: field(_NotesColumn.site),
        run: field(_NotesColumn.run),
        verticalOrDuration: field(_NotesColumn.verticalOrDuration),
        wing: field(_NotesColumn.wing),
        comment: field(_NotesColumn.comment),
        count: count,
        sourceNumber: startNumber?.toString(),
      ));
    }
    return result;
  }
}

enum _NotesColumn { date, site, run, verticalOrDuration, wing, comment }
