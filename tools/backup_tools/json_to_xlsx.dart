import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart';

const _usage = '''
Convert backup JSON into XLSX (ready for Google Sheets).

Usage:
  dart run tools/backup_tools/json_to_xlsx.dart <input_json> [output_xlsx]

Example:
  dart run tools/backup_tools/json_to_xlsx.dart tools/backup_bendahara_20260317_2239_plain.json
''';

Future<void> main(List<String> args) async {
  if (args.isEmpty || args.contains('--help') || args.contains('-h')) {
    stdout.write(_usage);
    exitCode = args.isEmpty ? 1 : 0;
    return;
  }

  final inputPath = args[0];
  final outputPath = args.length > 1 ? args[1] : _defaultOutputPath(inputPath);

  final inputFile = File(inputPath);
  if (!await inputFile.exists()) {
    stderr.writeln('Input file tidak ditemukan: $inputPath');
    exitCode = 2;
    return;
  }

  try {
    final raw = await inputFile.readAsString();
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Format JSON tidak valid (harus object).');
    }

    final excel = Excel.createExcel();
    final defaultSheetName = excel.getDefaultSheet();

    for (final entry in decoded.entries) {
      final sheetName = _safeSheetName(entry.key);
      final sheet = excel[sheetName];
      final value = entry.value;

      if (value is! List) {
        _writeSingleValueSheet(sheet, value);
        continue;
      }

      final rows = value
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      if (rows.isEmpty) {
        sheet.cell(CellIndex.indexByString('A1')).value =
            TextCellValue('No data');
        continue;
      }

      final headers = <String>{};
      for (final row in rows) {
        headers.addAll(row.keys);
      }
      final orderedHeaders = headers.toList()..sort();

      for (var col = 0; col < orderedHeaders.length; col++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0))
            .value = TextCellValue(orderedHeaders[col]);
      }

      for (var r = 0; r < rows.length; r++) {
        final row = rows[r];
        for (var c = 0; c < orderedHeaders.length; c++) {
          final key = orderedHeaders[c];
          final cellValue = row[key];
          sheet
              .cell(
                CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1),
              )
              .value = _toExcelCellValue(cellValue);
        }
      }
    }

    if (defaultSheetName != null && excel.tables.length > 1) {
      excel.delete(defaultSheetName);
    }

    final bytes = excel.save();
    if (bytes == null) {
      throw Exception('Gagal membuat file XLSX.');
    }

    final outFile = File(outputPath);
    await outFile.parent.create(recursive: true);
    await outFile.writeAsBytes(bytes, flush: true);

    stdout.writeln('XLSX berhasil dibuat: $outputPath');
  } catch (e) {
    stderr.writeln('Gagal convert JSON ke XLSX: $e');
    exitCode = 3;
  }
}

CellValue _toExcelCellValue(dynamic value) {
  if (value == null) return TextCellValue('');
  if (value is int) return IntCellValue(value);
  if (value is double) return DoubleCellValue(value);
  if (value is bool) return TextCellValue(value ? 'true' : 'false');
  if (value is String) return TextCellValue(value);
  return TextCellValue(jsonEncode(value));
}

void _writeSingleValueSheet(Sheet sheet, dynamic value) {
  sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('value');
  sheet.cell(CellIndex.indexByString('A2')).value = _toExcelCellValue(value);
}

String _safeSheetName(String name) {
  final invalidChars = RegExp(r'[:\\/?*\[\]]');
  final cleaned = name.replaceAll(invalidChars, '_');
  return cleaned.length <= 31 ? cleaned : cleaned.substring(0, 31);
}

String _defaultOutputPath(String inputPath) {
  final inputFile = File(inputPath);
  final parent = inputFile.parent.path;
  final filename = inputFile.uri.pathSegments.isNotEmpty
      ? inputFile.uri.pathSegments.last
      : 'backup.json';

  final dot = filename.lastIndexOf('.');
  final base = dot > 0 ? filename.substring(0, dot) : filename;
  return '$parent/${base}_for_google_sheets.xlsx';
}
