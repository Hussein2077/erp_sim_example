import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:erp_scale_sim/core/contracts/modules/module_caller.dart';
import 'package:erp_scale_sim/core/contracts/screens/screen_caller.dart';
import 'package:erp_scale_sim/core/contracts/screens/screen_registry.dart';
import 'package:erp_scale_sim/core/injection/core_injector.dart';
import 'package:erp_scale_sim_app/core/injection/injector.dart';
import 'package:erp_scale_sim_app/gen/registry.dart';
import 'package:erp_scale_sim_app/startup_report.dart';
import 'package:flutter/material.dart';

/// Wall-clock anchor set from JS before Dart main runs.
double? pageLoadEpochMs;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final params = Uri.base.queryParameters;
  final skipRuntime = params['skipRuntime'] == '1';
  final instantiateCount = int.tryParse(params['instantiate'] ?? '') ?? AppRegistry.screenCount;
  final warmCount = int.tryParse(params['warm'] ?? '') ?? 1;
  final pageIndex = int.tryParse(params['page'] ?? '') ?? 1;

  final report = StartupReport(pageLoadEpochMs: pageLoadEpochMs);

  report.mark('main() entry');

  await CoreInjector.initFirst();
  report.mark('CoreInjector.initFirst()');

  await GetItInjector.init();
  report.mark('GetItInjector.init()');

  ModuleCaller.callAllModules();
  report.mark('ModuleCaller.callAllModules() (${ScreenRegistry.count} defs)');

  final controllers = <dynamic>[];

  if (!skipRuntime) {
    final firstId = AppRegistry.screenIds.first;
    controllers.add(ScreenCaller.callCubit(firstId));
    report.mark('resolve first screen');

    final remaining = AppRegistry.screenIds.take(instantiateCount).skip(1);
    for (final id in remaining) {
      controllers.add(ScreenCaller.callCubit(id));
    }
    report.mark('resolve remaining ${remaining.length} screens');

    // Drive one operation per mixin unit on warmed screens
    final warmed = controllers.take(warmCount).toList();
    for (final ctrl in warmed) {
      await _driveOneOpPerUnit(ctrl);
    }
    report.mark('drive one op per unit');

    for (final ctrl in controllers) {
      await _closeController(ctrl);
    }
    report.mark('close controllers');
  }

  report.mark('first frame rendered');
  report.printReport();

  final displayId = AppRegistry.screenIds[(pageIndex - 1).clamp(0, AppRegistry.screenCount - 1)];

  runApp(ErpScaleSimApp(
    report: report,
    displayScreenId: displayId,
    arch: AppRegistry.arch,
  ));
}

Future<void> _driveOneOpPerUnit(dynamic ctrl) async {
  try {
    await (ctrl as dynamic).loadReactiveFormSessionScreen(force: true);
  } catch (_) {
    // Best-effort warmup
  }
}

Future<void> _closeController(dynamic ctrl) async {
  try {
    if (ctrl is BlocBase) {
      await ctrl.close();
    }
  } catch (_) {}
}

class ErpScaleSimApp extends StatelessWidget {
  const ErpScaleSimApp({
    super.key,
    required this.report,
    required this.displayScreenId,
    required this.arch,
  });

  final StartupReport report;
  final String displayScreenId;
  final String arch;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'erp_scale_sim',
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: StartupDashboard(
        report: report,
        displayScreenId: displayScreenId,
        arch: arch,
      ),
    );
  }
}

class StartupDashboard extends StatelessWidget {
  const StartupDashboard({
    super.key,
    required this.report,
    required this.displayScreenId,
    required this.arch,
  });

  final StartupReport report;
  final String displayScreenId;
  final String arch;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('erp_scale_sim ($arch)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Architecture: $arch', style: Theme.of(context).textTheme.titleLarge),
            Text('Screens: ${AppRegistry.screenCount} | Mixins: ${AppRegistry.mixinCount}'),
            Text('Display: $displayScreenId'),
            const SizedBox(height: 16),
            Expanded(child: StartupReportTable(report: report)),
          ],
        ),
      ),
    );
  }
}

class StartupReportTable extends StatelessWidget {
  const StartupReportTable({super.key, required this.report});
  final StartupReport report;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Phase')),
          DataColumn(label: Text('Elapsed (ms)')),
          DataColumn(label: Text('Delta (ms)')),
        ],
        rows: report.entries.map((e) {
          return DataRow(cells: [
            DataCell(Text(e.label)),
            DataCell(Text(e.elapsedMs.toStringAsFixed(1))),
            DataCell(Text(e.deltaMs.toStringAsFixed(1))),
          ]);
        }).toList(),
      ),
    );
  }
}
