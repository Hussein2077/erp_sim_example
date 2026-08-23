import 'dart:io';

void main(List<String> args) {
  final filePath = args.isNotEmpty ? args[0] : 'analyze_output.txt';
  final file = File(filePath);
  if (!file.existsSync()) {
    stdout.writeln('Log file $filePath does not exist');
    return;
  }

  final lines = file.readAsLinesSync();
  final errorsByCode = <String, int>{};
  final warningsByCode = <String, int>{};
  final infosByCode = <String, int>{};
  final errorsByFile = <String, int>{};
  final samples = <String, String>{};
  int totalErrors = 0;

  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;

    final parts = trimmed.split(' - ');
    if (parts.length >= 4) {
      final severity = parts[0].trim();
      final message = parts[1].trim();
      final loc = parts[2].trim();
      final code = parts[3].trim();

      if (severity == 'error') {
        totalErrors++;
        errorsByCode[code] = (errorsByCode[code] ?? 0) + 1;
        if (!samples.containsKey(code)) {
          samples[code] = '$message | AT: $loc';
        }
        final fileParts = loc.contains('/') ? loc.split('/') : loc.split('\\');
        final topFolder = fileParts.length > 1 ? fileParts[0] : loc;
        errorsByFile[topFolder] = (errorsByFile[topFolder] ?? 0) + 1;
      } else if (severity == 'warning') {
        warningsByCode[code] = (warningsByCode[code] ?? 0) + 1;
      } else if (severity == 'info') {
        infosByCode[code] = (infosByCode[code] ?? 0) + 1;
      }
    }
  }

  stdout.writeln('TOTAL ERRORS: $totalErrors');
  stdout.writeln('=== SUMMARY OF ERRORS ===');
  var sortedErrors = errorsByCode.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  for (var entry in sortedErrors) {
    stdout.writeln('ERROR CODE [${entry.key}]: ${entry.value} occurrences');
    stdout.writeln('   Sample: ${samples[entry.key]}');
  }

  stdout.writeln('\n=== ERRORS BY TOP FOLDER / MODULE ===');
  var sortedFiles = errorsByFile.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  for (var entry in sortedFiles) {
    stdout.writeln('${entry.key}: ${entry.value} errors');
  }

  stdout.writeln('\n=== SUMMARY OF WARNINGS ===');
  var sortedWarnings = warningsByCode.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  for (var entry in sortedWarnings) {
    stdout.writeln('WARNING CODE [${entry.key}]: ${entry.value} occurrences');
  }

  stdout.writeln('\n=== SUMMARY OF INFOS ===');
  var sortedInfos = infosByCode.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  for (var entry in sortedInfos) {
    stdout.writeln('INFO CODE [${entry.key}]: ${entry.value} occurrences');
  }
}
