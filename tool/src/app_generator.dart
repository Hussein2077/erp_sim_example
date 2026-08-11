import 'config.dart';
import 'utils.dart';

class AppGenerator {
  AppGenerator(this.config, this.root, this.moduleCount);

  final GenConfig config;
  final String root;
  final int moduleCount;
  final GenStats stats = GenStats();

  void generate() {
    _generateAppPubspec();
    _generateInjector();
    _generateRegistry();
  }

  void _write(String relPath, String content) {
    writeFile('$root/$relPath', content);
    stats.addFile(content);
  }

  void _generateAppPubspec() {
    final moduleDeps = List.generate(
      moduleCount,
      (i) {
        final id = padNum(i + 1, 2);
        return '  module_$id:\n    path: ../packages/module_$id';
      },
    ).join('\n');

    _write('app/pubspec.yaml', '''
name: erp_scale_sim_app
description: Flutter Web app shell for erp_scale_sim reproduction.
publish_to: 'none'
version: 1.0.0

environment:
  sdk: ^3.5.0

dependencies:
  flutter:
    sdk: flutter
  erp_scale_sim:
    path: ../
  flutter_bloc: ^9.1.0
  bloc: ^9.0.0
  get_it: ^8.0.3
$moduleDeps

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0

flutter:
  uses-material-design: true
''');
  }

  void _generateInjector() {
    final moduleInits = List.generate(
      moduleCount,
      (i) {
        final id = padNum(i + 1, 2);
        return "    M${id}InitGetIt.knowModule();";
      },
    ).join('\n');

    final imports = List.generate(
      moduleCount,
      (i) {
        final id = padNum(i + 1, 2);
        return "import 'package:module_$id/core/m${id}_injection/m${id}_init_get_it.dart';";
      },
    ).join('\n');

    _write('app/lib/core/injection/injector.dart', '''
import 'package:erp_scale_sim/features/common_feature/injection/common_feature_injection.dart';
$imports

class GetItInjector {
  static Future<void> init() async {
    CommonFeatureInjection.register();
$moduleInits
    await Future<void>.delayed(Duration.zero);
  }
}
''');
  }

  void _generateRegistry() {
    final screenIds = List.generate(config.screens, (i) => "'screen_${padNum(i + 1, 4)}'");
    _write('app/lib/gen/registry.dart', '''
class AppRegistry {
  static const arch = '${config.arch}';
  static const screenCount = ${config.screens};
  static const moduleCount = $moduleCount;
  static const mixinCount = ${config.mixins};

  static const screenIds = <String>[
    ${screenIds.join(',\n    ')}
  ];
}
''');
  }
}
