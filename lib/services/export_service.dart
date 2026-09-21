import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:uuid/uuid.dart';

import '../models/flight_entry.dart';

class ExportService {
  String toJson(List<FlightEntry> flights) {
    final list = flights.map((f) => f.toJson()).toList();
    return const JsonEncoder.withIndent('  ').convert(list);
  }

  String toCsv(List<FlightEntry> flights) {
    final buffer = StringBuffer();
    buffer.writeln('numero,date,site,run,denivele_duree,voile,nb_vols,commentaire');
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

  Future<List<FlightEntry>?> importFromFile() async {
    const jsonType = XTypeGroup(label: 'JSON', extensions: ['json']);
    const csvType = XTypeGroup(label: 'CSV', extensions: ['csv']);
    final file = await openFile(acceptedTypeGroups: [jsonType, csvType]);
    if (file == null) return null;
    final content = await file.readAsString();
    if (file.name.toLowerCase().endsWith('.csv')) {
      return _parseCsv(content);
    }
    return _parseJson(content);
  }

  List<FlightEntry> _parseJson(String content) {
    final list = jsonDecode(content) as List<dynamic>;
    return list
        .map((e) => FlightEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  List<FlightEntry> _parseCsv(String content) {
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

  /// Parses a table pasted from Apple Notes: tab-separated columns
  /// `Nº · Date · Lieu · Run · Dénivelé/Durée · Voile`, where the flight
  /// number column may hold a range ("6-8" = 3 grouped identical flights)
  /// and the date column may be left blank to mean "same date as the row
  /// above".
  List<FlightEntry> parseNotesTable(String raw) {
    final result = <FlightEntry>[];
    DateTime? lastDate;
    const uuid = Uuid();
    final numberPattern = RegExp(r'^\d+(-\d+)?$');
    final datePattern = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{2}|\d{4})$');

    for (final rawLine in raw.split('\n')) {
      final line = rawLine.trimRight();
      if (line.trim().isEmpty) continue;
      final fields = line.split('\t').map((f) => f.trim()).toList();
      if (fields.isEmpty) continue;

      final noField = fields[0];
      if (!numberPattern.hasMatch(noField)) continue; // header/title line

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

      final dateField = fields.length > 1 ? fields[1] : '';
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
        date: date,
        site: fields.length > 2 ? fields[2] : '',
        run: fields.length > 3 ? fields[3] : '',
        verticalOrDuration: fields.length > 4 ? fields[4] : '',
        wing: fields.length > 5 ? fields[5] : '',
        count: count,
        sourceNumber: startNumber?.toString(),
      ));
    }
    return result;
  }
}
