import 'dart:js_interop';

/// Startup timing report using performance.now() semantics.
class StartupReport {
  StartupReport({this.pageLoadEpochMs}) {
    _startMs = _nowMs();
    if (pageLoadEpochMs != null) {
      mark('page load -> main() entry', atMs: pageLoadEpochMs!);
    }
  }

  final double? pageLoadEpochMs;
  late final double _startMs;
  final List<StartupEntry> entries = [];

  double _nowMs() {
    try {
      return performance.now();
    } catch (_) {
      return DateTime.now().millisecondsSinceEpoch.toDouble();
    }
  }

  void mark(String label, {double? atMs}) {
    final elapsed = atMs ?? _nowMs();
    entries.add(StartupEntry(
      label: label,
      elapsedMs: elapsed - (pageLoadEpochMs ?? _startMs),
      deltaMs: entries.isEmpty
          ? elapsed - (pageLoadEpochMs ?? _startMs)
          : elapsed - (pageLoadEpochMs ?? _startMs) - entries.last.elapsedMs,
    ));
  }

  void printReport() {
    // ignore: avoid_print
    print('\n=== erp_scale_sim startup report ===');
    for (final e in entries) {
      // ignore: avoid_print
      print('  ${e.label}: ${e.elapsedMs.toStringAsFixed(1)} ms (+${e.deltaMs.toStringAsFixed(1)} ms)');
    }
    // ignore: avoid_print
    print('=====================================\n');
  }
}

class StartupEntry {
  StartupEntry({
    required this.label,
    required this.elapsedMs,
    required this.deltaMs,
  });

  final String label;
  final double elapsedMs;
  final double deltaMs;
}

@JS('performance')
external Performance get performance;

extension type Performance._(JSObject _) implements JSObject {
  external double now();
}
