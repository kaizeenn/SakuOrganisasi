import 'dart:convert';
import 'dart:io';

const _usage = '''
Normalize Apk Bendahara backup file (plain JSON).

Usage:
  dart run tools/backup_tools/decrypt_backup.dart <input_file> [output_file]

Examples:
  dart run tools/backup_tools/decrypt_backup.dart backup_bendahara_20260317_1200.json
  dart run tools/backup_tools/decrypt_backup.dart backup.json backup_plain.json
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
    stderr.writeln('File input tidak ditemukan: $inputPath');
    exitCode = 2;
    return;
  }

  try {
    final rawContent = await inputFile.readAsString();
    final jsonString = _readPlainJson(rawContent);
    final normalizedJson = _normalizeJson(jsonString);

    final outputFile = File(outputPath);
    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsString(normalizedJson);

    stdout.writeln('Berhasil menulis JSON tanpa enkripsi ke: $outputPath');
  } catch (error) {
    stderr.writeln('Gagal membuka backup: $error');
    exitCode = 3;
  }
}

String _readPlainJson(String content) {
  final trimmed = content.trim();

  try {
    jsonDecode(trimmed);
    return trimmed;
  } catch (_) {
    throw const FormatException('File bukan JSON backup yang valid.');
  }
}

String _normalizeJson(String jsonString) {
  final decoded = jsonDecode(jsonString);
  const encoder = JsonEncoder.withIndent('  ');
  return '${encoder.convert(decoded)}\n';
}

String _defaultOutputPath(String inputPath) {
  final inputFile = File(inputPath);
  final parent = inputFile.parent.path;
  final name = inputFile.uri.pathSegments.isNotEmpty
      ? inputFile.uri.pathSegments.last
      : 'backup.json';

  final dotIndex = name.lastIndexOf('.');
  final baseName = dotIndex > 0 ? name.substring(0, dotIndex) : name;
  return '$parent/${baseName}_plain.json';
}
