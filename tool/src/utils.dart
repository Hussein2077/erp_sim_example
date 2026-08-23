import 'dart:io';

class GenStats {
  int files = 0;
  int lines = 0;

  void addFile(String content) {
    files++;
    lines += content.split('\n').length;
  }
}

void writeFile(String path, String content) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
}

void deleteDirIfExists(String path) {
  final dir = Directory(path);
  if (dir.existsSync()) {
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
  }
}

int countDartFiles(String root) {
  final dir = Directory(root);
  if (!dir.existsSync()) return 0;
  int count = 0;
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      count++;
    }
  }
  return count;
}

int countDartLines(String root) {
  final dir = Directory(root);
  if (!dir.existsSync()) return 0;
  int lines = 0;
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      lines += entity.readAsLinesSync().length;
    }
  }
  return lines;
}

String padNum(int n, int width) => n.toString().padLeft(width, '0');

/// Joins [items] one per line with [indent], comma-separated except on the last.
String joinIndented(List<String> items, {String indent = '        '}) {
  if (items.isEmpty) return '';
  final buf = StringBuffer();
  for (var i = 0; i < items.length; i++) {
    final suffix = i < items.length - 1 ? ',' : '';
    buf.writeln('$indent${items[i]}$suffix');
  }
  return buf.toString().trimRight();
}
