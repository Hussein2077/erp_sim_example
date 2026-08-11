#!/usr/bin/env dart
/// Benchmark harness for erp_scale_sim compile times.
///
/// Usage:
///   dart run tool/bench.dart --screens=800 --mode=all
///   dart run tool/bench.dart --screens=200,400,800 --mode=ddc
///   dart run tool/bench.dart --report
import 'dart:io';

Future<void> main(List<String> args) async {
  final screensArg = _arg(args, '--screens', '800');
  final mode = _arg(args, '--mode', 'ddc');
  final repeat = int.parse(_arg(args, '--repeat', '1'));
  final reportOnly = args.contains('--report');

  final root = Directory.current.path;
  final resultsDir = '$root/bench/results';
  Directory(resultsDir).createSync(recursive: true);

  if (reportOnly) {
    _generateReport(resultsDir);
    return;
  }

  final screenCounts = screensArg.split(',').map(int.parse).toList();
  final modes = mode == 'all' ? ['ddc', 'release'] : [mode];
  final archs = ['composition', 'mixin', 'mixin-shared'];

  final csv = StringBuffer('arch,screens,mode,pub_get_s,compile_s,dart_files,dart_lines\n');

  // Floor measurement
  stdout.writeln('=== Floor measurement (1 module, 1 screen, 2 mixins) ===');
  for (final m in modes) {
    final floor = await _runBench(
      root: root,
      arch: 'composition',
      screens: 1,
      modules: 1,
      mixins: 2,
      mode: m,
    );
    stdout.writeln('  floor $m: ${floor.compileSeconds}s compile, ${floor.pubGetSeconds}s pub get');
    _writeLog(resultsDir, 'floor_${m}.log', floor.log);
  }

  for (final arch in archs) {
    for (final screenCount in screenCounts) {
      for (final m in modes) {
        for (var r = 0; r < repeat; r++) {
          stdout.writeln('=== $arch / $screenCount screens / $m (run ${r + 1}/$repeat) ===');
          final result = await _runBench(
            root: root,
            arch: arch,
            screens: screenCount,
            modules: 15,
            mixins: 29,
            mode: m,
          );
          csv.writeln('$arch,$screenCount,$m,${result.pubGetSeconds},${result.compileSeconds},${result.dartFiles},${result.dartLines}');
          _writeLog(resultsDir, '${arch}_${screenCount}_${m}_$r.log', result.log);
          stdout.writeln('  pub get: ${result.pubGetSeconds}s');
          stdout.writeln('  compile: ${result.compileSeconds}s');
        }
      }
    }
  }

  File('$resultsDir/results.csv').writeAsStringSync(csv.toString());
  _generateReport(resultsDir);
  stdout.writeln('\nResults written to bench/results/');
}

String _arg(List<String> args, String name, String defaultValue) {
  for (final arg in args) {
    if (arg.startsWith('$name=')) return arg.split('=')[1];
  }
  return defaultValue;
}

class BenchResult {
  BenchResult({
    required this.pubGetSeconds,
    required this.compileSeconds,
    required this.dartFiles,
    required this.dartLines,
    required this.log,
  });

  final double pubGetSeconds;
  final double compileSeconds;
  final int dartFiles;
  final int dartLines;
  final String log;
}

Future<BenchResult> _runBench({
  required String root,
  required String arch,
  required int screens,
  required int modules,
  required int mixins,
  required String mode,
}) async {
  final log = StringBuffer();

  // Generate workspace
  log.writeln('Generating arch=$arch screens=$screens modules=$modules mixins=$mixins');
  final genResult = await Process.run(
    'dart',
    [
      'run',
      'tool/generate.dart',
      '--arch=$arch',
      '--screens=$screens',
      '--modules=$modules',
      '--mixins=$mixins',
    ],
    workingDirectory: root,
  );
  log.writeln(genResult.stdout);
  log.writeln(genResult.stderr);

  final appDir = '$root/app';

  // flutter clean
  log.writeln('flutter clean');
  final cleanResult = await Process.run('flutter', ['clean'], workingDirectory: appDir);
  log.writeln(cleanResult.stdout);
  log.writeln(cleanResult.stderr);

  // flutter pub get (timed)
  final pubGetStart = DateTime.now();
  log.writeln('flutter pub get');
  final pubGetResult = await Process.run('flutter', ['pub', 'get'], workingDirectory: appDir);
  log.writeln(pubGetResult.stdout);
  log.writeln(pubGetResult.stderr);
  final pubGetSeconds = DateTime.now().difference(pubGetStart).inMilliseconds / 1000.0;

  // Compile (timed)
  final compileStart = DateTime.now();
  ProcessResult compileResult;
  if (mode == 'release') {
    log.writeln('flutter build web --release');
    compileResult = await Process.run(
      'flutter',
      ['build', 'web', '--release'],
      workingDirectory: appDir,
    );
  } else {
    log.writeln('flutter run -d web-server --web-port=0');
    compileResult = await Process.run(
      'flutter',
      ['run', '-d', 'web-server', '--web-port=0'],
      workingDirectory: appDir,
    );
  }
  log.writeln(compileResult.stdout);
  log.writeln(compileResult.stderr);
  final compileSeconds = DateTime.now().difference(compileStart).inMilliseconds / 1000.0;

  // Count files/lines
  var dartFiles = 0;
  var dartLines = 0;
  for (final dir in ['$root/lib', '$root/packages', '$root/app/lib/core', '$root/app/lib/gen']) {
    dartFiles += _countFiles(dir);
    dartLines += _countLines(dir);
  }

  return BenchResult(
    pubGetSeconds: pubGetSeconds,
    compileSeconds: compileSeconds,
    dartFiles: dartFiles,
    dartLines: dartLines,
    log: log.toString(),
  );
}

int _countFiles(String root) {
  final dir = Directory(root);
  if (!dir.existsSync()) return 0;
  return dir.listSync(recursive: true).where((e) => e.path.endsWith('.dart')).length;
}

int _countLines(String root) {
  final dir = Directory(root);
  if (!dir.existsSync()) return 0;
  var lines = 0;
  for (final e in dir.listSync(recursive: true)) {
    if (e is File && e.path.endsWith('.dart')) {
      lines += e.readAsLinesSync().length;
    }
  }
  return lines;
}

void _writeLog(String resultsDir, String name, String content) {
  Directory('$resultsDir/logs').createSync(recursive: true);
  File('$resultsDir/logs/$name').writeAsStringSync(content);
}

void _generateReport(String resultsDir) {
  final csvFile = File('$resultsDir/results.csv');
  if (!csvFile.existsSync()) {
    stdout.writeln('No results.csv found. Run benchmarks first.');
    return;
  }

  final rows = csvFile.readAsLinesSync().skip(1).toList();
  final buf = StringBuffer('# erp_scale_sim benchmark results\n\n');
  buf.writeln('Generated: ${DateTime.now().toIso8601String()}\n');
  buf.writeln('| arch | screens | mode | pub_get_s | compile_s | dart_files | dart_lines |');
  buf.writeln('|---|---|---|---|---|---|---|');
  for (final row in rows) {
    final cols = row.split(',');
    if (cols.length >= 7) {
      buf.writeln('| ${cols[0]} | ${cols[1]} | ${cols[2]} | ${cols[3]} | ${cols[4]} | ${cols[5]} | ${cols[6]} |');
    }
  }

  File('$resultsDir/summary.md').writeAsStringSync(buf.toString());
  stdout.writeln(buf.toString());
}
