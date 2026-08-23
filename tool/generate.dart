#!/usr/bin/env dart
/// Generates the erp_scale_sim synthetic multi-package workspace.
///
/// Usage:
///   dart run tool/generate.dart --arch=mixin --modules=15 --screens=800 --mixins=29
/// dart run tool/generate.dart --arch=composition --modules=15 --screens=800 --mixins=29
///  dart run tool/generate.dart --arch=mixin-shared --modules=15 --screens=800 --mixins=29

library;

import 'dart:io';

import 'src/app_generator.dart';
import 'src/config.dart';
import 'src/core_generator.dart';
import 'src/module_generator.dart';
import 'src/utils.dart';

Future<void> main(List<String> args) async {
  final config = GenConfig.fromArgs(args);
  final root = Directory.current.path;

  stdout.writeln('erp_scale_sim generator');
  stdout.writeln('  arch=${config.arch} modules=${config.modules} '
      'screens=${config.screens} mixins=${config.mixins}');
  stdout.writeln('  module-mixins=${config.moduleMixins} widgets=${config.widgets} '
      'methods=${config.methods} chain=${config.chain} cross=${config.cross}');
  stdout.writeln();

  // Clean generated dirs
  deleteDirIfExists('$root/lib');
  deleteDirIfExists('$root/packages');
  deleteDirIfExists('$root/app/lib/core');
  deleteDirIfExists('$root/app/lib/gen');

  // Remove default flutter app files at root if present
  final defaultMain = File('$root/lib/main.dart');
  if (defaultMain.existsSync()) defaultMain.deleteSync();

  final coreGen = CoreGenerator(config, root);
  coreGen.generate();

  final moduleGen = ModuleGenerator(config, root, coreGen.units);
  moduleGen.generate();

  final appGen = AppGenerator(config, root, config.modules);
  appGen.generate();

  // Write arch marker for bench
  writeFile('$root/.gen_arch', config.arch);

  final dartFiles = countDartFiles(root) - countDartFiles('$root/tool');
  final dartLines = countDartLines(root) -
      countDartLines('$root/tool') -
      countDartLines('$root/app/lib/main.dart') -
      countDartLines('$root/app/lib/startup_report.dart');

  stdout.writeln('Generation complete (${config.arch})');
  stdout.writeln('  packages: ${1 + config.modules} (core + ${config.modules} modules + app shell)');
  stdout.writeln('  dart files: ~$dartFiles');
  stdout.writeln('  lines of Dart: ~$dartLines');
  stdout.writeln();
  stdout.writeln('Next steps:');
  stdout.writeln('  cd app');
  stdout.writeln('  flutter pub get');
  stdout.writeln('  flutter run -d chrome');
}
