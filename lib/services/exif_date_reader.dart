import 'dart:typed_data';

/// Minimal JPEG EXIF parser that extracts the "DateTimeOriginal" (falling
/// back to "DateTime") tag. Deliberately self-contained (pure byte parsing,
/// no dart:io) so it compiles for Flutter web, unlike most EXIF packages.
DateTime? readJpegExifDate(Uint8List bytes) {
  try {
    if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) return null;
    var offset = 2;
    while (offset + 4 <= bytes.length) {
      if (bytes[offset] != 0xFF) break;
      final marker = bytes[offset + 1];
      if (marker == 0xD8 || marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) {
        offset += 2;
        continue;
      }
      if (marker == 0xDA || marker == 0xD9) break; // start of scan / end of image
      if (offset + 4 > bytes.length) break;
      final segmentLength = (bytes[offset + 2] << 8) | bytes[offset + 3];
      if (marker == 0xE1) {
        final exifStart = offset + 4;
        if (exifStart + 6 <= bytes.length &&
            bytes[exifStart] == 0x45 && // E
            bytes[exifStart + 1] == 0x78 && // x
            bytes[exifStart + 2] == 0x69 && // i
            bytes[exifStart + 3] == 0x66 && // f
            bytes[exifStart + 4] == 0x00 &&
            bytes[exifStart + 5] == 0x00) {
          final date = _parseTiff(bytes, exifStart + 6);
          if (date != null) return date;
        }
      }
      offset += 2 + segmentLength;
    }
  } catch (_) {
    // Malformed/unsupported file: no date available.
  }
  return null;
}

DateTime? _parseTiff(Uint8List bytes, int tiffStart) {
  if (tiffStart + 8 > bytes.length) return null;
  final bd = ByteData.sublistView(bytes);
  final Endian endian;
  if (bytes[tiffStart] == 0x49 && bytes[tiffStart + 1] == 0x49) {
    endian = Endian.little;
  } else if (bytes[tiffStart] == 0x4D && bytes[tiffStart + 1] == 0x4D) {
    endian = Endian.big;
  } else {
    return null;
  }

  final ifd0Offset = tiffStart + bd.getUint32(tiffStart + 4, endian);
  final ifd0 = _readIfd(bytes, bd, tiffStart, ifd0Offset, endian);

  final exifSubIfdPointer = ifd0[0x8769];
  if (exifSubIfdPointer is int) {
    final subIfd = _readIfd(bytes, bd, tiffStart, tiffStart + exifSubIfdPointer, endian);
    final original = subIfd[0x9003] ?? subIfd[0x9004];
    if (original is String) {
      final parsed = _parseExifDateString(original);
      if (parsed != null) return parsed;
    }
  }

  final modifyDate = ifd0[0x0132];
  if (modifyDate is String) return _parseExifDateString(modifyDate);
  return null;
}

/// Reads an IFD, decoding only what's needed to reach date tags: ASCII
/// strings (type 2), SHORT (type 3) and LONG (type 4, used for SubIFD
/// pointers).
Map<int, Object> _readIfd(
  Uint8List bytes,
  ByteData bd,
  int tiffStart,
  int ifdOffset,
  Endian endian,
) {
  final result = <int, Object>{};
  if (ifdOffset < 0 || ifdOffset + 2 > bytes.length) return result;
  final entryCount = bd.getUint16(ifdOffset, endian);
  for (var i = 0; i < entryCount; i++) {
    final entryOffset = ifdOffset + 2 + i * 12;
    if (entryOffset + 12 > bytes.length) break;
    final tag = bd.getUint16(entryOffset, endian);
    final type = bd.getUint16(entryOffset + 2, endian);
    final count = bd.getUint32(entryOffset + 4, endian);
    final valueFieldOffset = entryOffset + 8;

    if (type == 2) {
      final dataOffset = count <= 4
          ? valueFieldOffset
          : tiffStart + bd.getUint32(valueFieldOffset, endian);
      if (dataOffset >= 0 && dataOffset + count <= bytes.length) {
        final strBytes = bytes.sublist(dataOffset, dataOffset + count);
        final nullIndex = strBytes.indexOf(0);
        result[tag] = String.fromCharCodes(
            nullIndex >= 0 ? strBytes.sublist(0, nullIndex) : strBytes);
      }
    } else if (type == 3) {
      result[tag] = bd.getUint16(valueFieldOffset, endian);
    } else if (type == 4) {
      result[tag] = bd.getUint32(valueFieldOffset, endian);
    }
  }
  return result;
}

DateTime? _parseExifDateString(String raw) {
  final match =
      RegExp(r'^(\d{4}):(\d{2}):(\d{2}) (\d{2}):(\d{2}):(\d{2})').firstMatch(raw);
  if (match == null) return null;
  try {
    return DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
      int.parse(match.group(6)!),
    );
  } catch (_) {
    return null;
  }
}
