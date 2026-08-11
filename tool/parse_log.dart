import 'dart:io';

void main() {
  final file = File(r'C:\Users\Ultimate\.gemini\antigravity\brain\37cda67c-41dc-41b2-9684-e52672dbbdfa\.system_generated\tasks\task-139.log');
  if (!file.existsSync()) {
    print('task-139.log does not exist');
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
        final fileParts = loc.split('\\');
        final topFolder = fileParts.length > 1 ? fileParts[0] : loc;
        errorsByFile[topFolder] = (errorsByFile[topFolder] ?? 0) + 1;
      } else if (severity == 'warning') {
        warningsByCode[code] = (warningsByCode[code] ?? 0) + 1;
      } else if (severity == 'info') {
        infosByCode[code] = (infosByCode[code] ?? 0) + 1;
      }
    }
  }

  print('TOTAL ERRORS: $totalErrors');
  print('=== SUMMARY OF ERRORS ===');
  var sortedErrors = errorsByCode.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  for (var entry in sortedErrors) {
    print('ERROR CODE [${entry.key}]: ${entry.value} occurrences');
    print('   Sample: ${samples[entry.key]}');
  }

  print('\n=== ERRORS BY TOP FOLDER / MODULE ===');
  var sortedFiles = errorsByFile.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  for (var entry in sortedFiles) {
    print('${entry.key}: ${entry.value} errors');
  }

  print('\n=== SUMMARY OF WARNINGS ===');
  var sortedWarnings = warningsByCode.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  for (var entry in sortedWarnings) {
    print('WARNING CODE [${entry.key}]: ${entry.value} occurrences');
  }

  print('\n=== SUMMARY OF INFOS ===');
  var sortedInfos = infosByCode.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  for (var entry in sortedInfos) {
    print('INFO CODE [${entry.key}]: ${entry.value} occurrences');
  }
}
