/// CLI configuration and constants for the erp_scale_sim generator.
class GenConfig {
  GenConfig({
    required this.arch,
    required this.modules,
    required this.screens,
    required this.mixins,
    required this.moduleMixins,
    required this.widgets,
    required this.methods,
    required this.chain,
    required this.cross,
  });

  final String arch; // composition | mixin | mixin-shared
  final int modules;
  final int screens;
  final int mixins;
  final int moduleMixins;
  final int widgets;
  final int methods;
  final int chain;
  final int cross;

  bool get isComposition => arch == 'composition';
  bool get isMixinShared => arch == 'mixin-shared';
  bool get isMixin => arch == 'mixin';

  static GenConfig fromArgs(List<String> args) {
    String arch = 'mixin';
    int modules = 15;
    int screens = 800;
    int mixins = 29;
    int moduleMixins = 3;
    int widgets = 24;
    int methods = 5;
    int chain = 4;
    int cross = 3;

    for (final arg in args) {
      if (arg.startsWith('--arch=')) {
        arch = arg.split('=')[1];
      } else if (arg.startsWith('--modules=')) {
        modules = int.parse(arg.split('=')[1]);
      } else if (arg.startsWith('--screens=')) {
        screens = int.parse(arg.split('=')[1]);
      } else if (arg.startsWith('--mixins=')) {
        mixins = int.parse(arg.split('=')[1]);
      } else if (arg.startsWith('--module-mixins=')) {
        moduleMixins = int.parse(arg.split('=')[1]);
      } else if (arg.startsWith('--widgets=')) {
        widgets = int.parse(arg.split('=')[1]);
      } else if (arg.startsWith('--methods=')) {
        methods = int.parse(arg.split('=')[1]);
      } else if (arg.startsWith('--chain=')) {
        chain = int.parse(arg.split('=')[1]);
      } else if (arg.startsWith('--cross=')) {
        cross = int.parse(arg.split('=')[1]);
      }
    }

    if (!['composition', 'mixin', 'mixin-shared'].contains(arch)) {
      throw ArgumentError('Invalid --arch: $arch');
    }

    return GenConfig(
      arch: arch,
      modules: modules,
      screens: screens,
      mixins: mixins,
      moduleMixins: moduleMixins,
      widgets: widgets,
      methods: methods,
      chain: chain,
      cross: cross,
    );
  }
}

/// Real mixin unit names from onyx_ix FeatureBloc.
const List<String> coreMixinUnits = [
  'reactive_form_session',
  'feature_body_mapping',
  'focus',
  'totals',
  'grid_manager',
  'load_scr',
  'vlds',
  'update',
  'setup',
  'delete',
  'approved',
  'posting',
  'suspend',
  'ui',
  'search',
  'filter',
  'export_data',
  'import_data',
  'print_scr',
  'audit',
  'workflow',
  'attachment',
  'notification',
  'permission',
  'history',
  'comment',
  'link_key',
  'validator',
  'action_bar',
];

/// Non-generic mixins (no type parameter).
const Set<String> nonGenericMixins = {'feature_body_mapping'};

String toPascal(String snake) {
  return snake
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join('');
}

String toCamel(String snake) {
  final p = toPascal(snake);
  return p.isEmpty ? p : '${p[0].lowerCase()}${p.substring(1)}';
}

extension on String {
  String lowerCase() => toLowerCase();
}

String mixinClassName(String unit) => '${toPascal(unit)}Mixin';
String mixinContractName(String unit) => 'I${toPascal(unit)}Mixin';
String mixinStateClass(String unit) => '_${toPascal(unit)}MixinState';
String eventClassName(String unit) => '${toPascal(unit)}Event';
String useCaseClassName(String unit) => '${toPascal(unit)}UseCase';
String capabilityClassName(String unit) => '${toPascal(unit)}Capability';

bool isCoreMixin(String unit) {
  const ops = {
    'delete',
    'approved',
    'posting',
    'suspend',
    'export_data',
    'import_data',
    'print_scr',
    'audit',
    'workflow',
    'action_bar',
  };
  return !ops.contains(unit);
}

String mixinDir(String unit) =>
    isCoreMixin(unit) ? 'mixins/core' : 'mixins/operations';

String eventDir(String unit) =>
    isCoreMixin(unit) ? 'events/core' : 'events/operations';
