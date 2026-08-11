import 'config.dart';
import 'templates.dart';
import 'utils.dart';

class ModuleGenerator {
  ModuleGenerator(this.config, this.root, this.coreUnits);

  final GenConfig config;
  final String root;
  final List<String> coreUnits;
  final GenStats stats = GenStats();

  void generate() {
    final screensPerModule = (config.screens / config.modules).ceil();
    var screenIndex = 0;

    for (var m = 1; m <= config.modules; m++) {
      final moduleId = padNum(m, 2);
      final moduleScreens = <int>[];
      for (var s = 0; s < screensPerModule && screenIndex < config.screens; s++) {
        screenIndex++;
        moduleScreens.add(screenIndex);
      }
      _generateModule(moduleId, m, moduleScreens);
    }
  }

  void _write(String relPath, String content) {
    writeFile('$root/$relPath', content);
    stats.addFile(content);
  }

  void _generateModule(String moduleId, int moduleNum, List<int> screenIds) {
    final pkg = 'module_$moduleId';
    final prefix = 'M$moduleId';
    final blocName = 'Module${moduleId}Bloc';
    final contractName = 'IModule${moduleId}Bloc';

    _write('packages/$pkg/pubspec.yaml', '''
name: $pkg
description: Generated module package $moduleId for erp_scale_sim.
publish_to: 'none'
version: 1.0.0

environment:
  sdk: ^3.5.0

dependencies:
  flutter:
    sdk: flutter
  erp_scale_sim:
    path: ../../
  flutter_bloc: ^9.1.0
  equatable: ^2.0.7
  get_it: ^8.0.3

flutter:
  uses-material-design: true
''');

    _write('packages/$pkg/lib/$pkg.dart', '''
export 'screens.dart';
export 'core/m${moduleId}_injection/m${moduleId}_init_get_it.dart';
''');

    // Module mixins and events
    for (var i = 0; i < config.moduleMixins; i++) {
      _write(
        'packages/$pkg/lib/src/common/presentation/controllers/mixins/module_${moduleId}_mixin_$i.dart',
        _moduleMixin(moduleId, i),
      );
      _write(
        'packages/$pkg/lib/src/common/presentation/controllers/events/module_${moduleId}_event_$i.dart',
        _moduleEvent(moduleId, i),
      );
    }

    _write(
      'packages/$pkg/lib/src/common/presentation/controllers/bloc/module_${moduleId}_bloc.dart',
      _moduleBloc(moduleId, blocName, contractName),
    );

    _write(
      'packages/$pkg/lib/src/common/presentation/controllers/bloc/module_${moduleId}_contract_bloc.dart',
      _moduleContract(moduleId, contractName),
    );

    // Screens
    for (final screenNum in screenIds) {
      final screenId = padNum(screenNum, 4);
      _generateScreen(pkg, moduleId, moduleNum, screenId, blocName);
    }

    // Module injection + screens registry
    _write(
      'packages/$pkg/lib/core/m${moduleId}_injection/m${moduleId}_init_get_it.dart',
      _moduleInitGetIt(moduleId, prefix, screenIds),
    );

    _write('packages/$pkg/lib/screens.dart', _screensRegistry(moduleId, screenIds));
  }

  String _moduleMixin(String moduleId, int index) {
    return '''
import 'package:erp_scale_sim/core/src/common_app_export.dart';
import 'package:erp_scale_sim/features/common_feature/presentation/controllers/bloc/feature_bloc.dart';
import 'package:erp_scale_sim/features/common_feature/presentation/controllers/state/feature_state.dart';
import '../events/module_${moduleId}_event_$index.dart';

abstract class IModule${moduleId}Mixin$index<T extends FeatureState> {
  SubState<Map<String, dynamic>>? get module${moduleId}State$index;
  Future<void> runModule${moduleId}Op$index({int payload = 0});
}

class _Module${moduleId}Mixin${index}State {
  int count = 0;
  final Map<String, dynamic> cache = {};
}

mixin Module${moduleId}Mixin$index<T extends FeatureState> on FeatureBloc<T>
    implements IModule${moduleId}Mixin$index<T> {
  final _Module${moduleId}Mixin${index}State _state = _Module${moduleId}Mixin${index}State();

  @override
  SubState<Map<String, dynamic>>? get module${moduleId}State$index =>
      SubState.loaded(_state.cache);

  void registerModule${moduleId}Mixin${index}Handlers() {
    on<Module${moduleId}Event$index>((event, emit) async {
      _state.count++;
      _state.cache['op'] = event.payload;
      emit(state.copyWith(loaderStatus: LoaderStatus.loaded) as T);
    });
  }

  @override
  Future<void> runModule${moduleId}Op$index({int payload = 0}) async {
    add(Module${moduleId}Event$index(payload: payload));
  }
}
''';
  }

  String _moduleEvent(String moduleId, int index) {
    return '''
import 'package:equatable/equatable.dart';

class Module${moduleId}Event$index extends Equatable {
  const Module${moduleId}Event$index({this.payload = 0});
  final int payload;

  @override
  List<Object?> get props => [payload];
}
''';
  }

  String _moduleBloc(String moduleId, String blocName, String contractName) {
    if (config.isComposition) {
      return '''
import 'package:erp_scale_sim/core/src/common_app_export.dart';
import 'package:erp_scale_sim/features/common_feature/presentation/controllers/bloc/feature_controller.dart';

abstract class $blocName extends FeatureController {
  $blocName({
    required super.featureUseCases,
    required super.screenId,
    required super.initialState,
  });
}
''';
    }

    final moduleMixinLines = List.generate(
      config.moduleMixins,
      (i) => 'Module${moduleId}Mixin$i<T>',
    );
    final withClause = joinIndented(moduleMixinLines);
    final moduleRegistrations = List.generate(
      config.moduleMixins,
      (i) => '    registerModule${moduleId}Mixin${i}Handlers();',
    ).join('\n');

    return '''
import 'package:erp_scale_sim/core/src/common_app_export.dart';
import 'package:erp_scale_sim/features/common_feature/presentation/controllers/bloc/feature_bloc.dart';
import 'package:erp_scale_sim/features/common_feature/domain/use_cases/feature_use_cases.dart';
import 'package:erp_scale_sim/features/common_feature/presentation/controllers/state/feature_state.dart';
import 'module_${moduleId}_contract_bloc.dart';
${List.generate(config.moduleMixins, (i) => "import '../mixins/module_${moduleId}_mixin_$i.dart';").join('\n')}

abstract class $blocName<T extends FeatureState> extends FeatureBloc<T>
    with
$withClause
    implements $contractName<T> {
  $blocName({
    required FeatureUseCases featureUseCases,
    required String screenId,
    required T initialState,
  }) : super(
          featureUseCases: featureUseCases,
          screenId: screenId,
          initialState: initialState,
        ) {
    registerModule${moduleId}Handlers();
  }

  void registerModule${moduleId}Handlers() {
$moduleRegistrations
  }
}
''';
  }

  String _moduleContract(String moduleId, String contractName) {
    final contracts = joinIndented(
      List.generate(config.moduleMixins, (i) => 'IModule${moduleId}Mixin$i<T>'),
      indent: '    ',
    );
    return '''
import 'package:erp_scale_sim/features/common_feature/presentation/controllers/state/feature_state.dart';
${List.generate(config.moduleMixins, (i) => "import '../mixins/module_${moduleId}_mixin_$i.dart';").join('\n')}

abstract class $contractName<T extends FeatureState> implements
$contracts {}
''';
  }

  void _generateScreen(String pkg, String moduleId, int moduleNum, String screenId, String blocName) {
    final stateType = _stateTypeName(screenId);
    final blocClass = 'Screen${screenId}Bloc';

    if (!config.isComposition) {
      _write(
        'packages/$pkg/lib/src/features/screen_$screenId/presentation/controllers/bloc/state/screen_${screenId}_state.dart',
        _screenState(screenId, stateType),
      );
    }

    _write(
      'packages/$pkg/lib/src/features/screen_$screenId/presentation/controllers/bloc/screen_${screenId}_bloc.dart',
      _screenBloc(moduleId, screenId, blocName, blocClass, stateType),
    );

    _write(
      'packages/$pkg/lib/src/features/screen_$screenId/presentation/def/screen_${screenId}_def.dart',
      _screenDef(pkg, moduleId, screenId, blocClass),
    );

    _write(
      'packages/$pkg/lib/src/features/screen_$screenId/presentation/view/screen_${screenId}_view.dart',
      _screenView(screenId, config.widgets),
    );

    // Barrel exports for screen
    _write(
      'packages/$pkg/lib/src/features/screen_$screenId/screen_$screenId.dart',
      "export 'presentation/def/screen_${screenId}_def.dart';",
    );
  }

  String _stateTypeName(String screenId) {
    if (config.isMixinShared || config.isComposition) {
      return 'FeatureState';
    }
    return 'Screen${screenId}State';
  }

  String _screenState(String screenId, String stateType) {
    if (stateType == 'FeatureState') return '';
    return '''
import 'package:erp_scale_sim/core/src/common_app_export.dart';
import 'package:erp_scale_sim/features/common_feature/presentation/controllers/state/feature_state.dart';
import 'package:erp_scale_sim/features/common_feature/presentation/controllers/state/feature_state_props.dart';

class Screen${screenId}State extends FeatureState {
  const Screen${screenId}State({
    super.loaderStatus,
    super.stateProps,
    super.screenId,
  });

  @override
  Screen${screenId}State copyWith({
    LoaderStatus? loaderStatus,
    FeatureStateProps? stateProps,
    String? screenId,
  }) {
    return Screen${screenId}State(
      loaderStatus: loaderStatus ?? this.loaderStatus,
      stateProps: stateProps ?? this.stateProps,
      screenId: screenId ?? this.screenId,
    );
  }
}
''';
  }

  String _screenBloc(String moduleId, String screenId, String moduleBloc, String blocClass, String stateType) {
    if (config.isComposition) {
      return '''
import 'package:erp_scale_sim/core/src/common_app_export.dart';
import 'package:erp_scale_sim/features/common_feature/injection/common_feature_injection.dart';
import 'package:erp_scale_sim/features/common_feature/presentation/controllers/state/feature_state.dart';
import 'package:erp_scale_sim/features/common_feature/domain/use_cases/feature_use_cases.dart';
import 'package:module_$moduleId/src/common/presentation/controllers/bloc/module_${moduleId}_bloc.dart';

class $blocClass extends Module${moduleId}Bloc {
  $blocClass()
      : super(
          featureUseCases: ScreenCaller.getService<FeatureUseCases>(),
          screenId: 'screen_$screenId',
          initialState: FeatureState(screenId: 'screen_$screenId'),
        ) {
    CommonFeatureInjection.register();
  }
}
''';
    }

    final stateImport = stateType == 'FeatureState'
        ? "import 'package:erp_scale_sim/features/common_feature/presentation/controllers/state/feature_state.dart';"
        : "import 'state/screen_${screenId}_state.dart';";

    final initialState = stateType == 'FeatureState'
        ? 'FeatureState(screenId: \'screen_$screenId\')'
        : 'Screen${screenId}State(screenId: \'screen_$screenId\')';

    return '''
import 'package:erp_scale_sim/core/src/common_app_export.dart';
import 'package:erp_scale_sim/features/common_feature/injection/common_feature_injection.dart';
import 'package:erp_scale_sim/features/common_feature/domain/use_cases/feature_use_cases.dart';
import 'package:module_$moduleId/src/common/presentation/controllers/bloc/module_${moduleId}_bloc.dart';
$stateImport

class $blocClass extends Module${moduleId}Bloc<$stateType> {
  $blocClass()
      : super(
          featureUseCases: ScreenCaller.getService<FeatureUseCases>(),
          screenId: 'screen_$screenId',
          initialState: $initialState,
        ) {
    CommonFeatureInjection.register();
    registerScreen${screenId}Handlers();
  }

  void registerScreen${screenId}Handlers() {
    // Screen-local handler registration hook
  }
}
''';
  }

  String _screenDef(String pkg, String moduleId, String screenId, String blocClass) {
    return '''
import 'package:erp_scale_sim/core/src/common_app_export.dart';
import 'package:erp_scale_sim/features/common_feature/presentation/template/common_feature_view.dart';
import '../controllers/bloc/screen_${screenId}_bloc.dart';
import '../view/screen_${screenId}_view.dart';

class Screen${screenId}Def implements ScreenDefinition {
  @override
  String get screenId => 'screen_$screenId';

  @override
  String get moduleId => 'module_$moduleId';

  @override
  String get title => 'Screen $screenId';

  @override
  dynamic Function() get createBloc => () => $blocClass();

  @override
  Widget Function(BuildContext context, dynamic bloc) get buildView =>
      (context, bloc) => Screen${screenId}View(bloc: bloc as $blocClass);
}
''';
  }

  String _screenView(String screenId, int widgets) {
    final fields = List.generate(
      widgets,
      (i) => '          FeatureField(label: \'Field $i\', value: \'screen_$screenId-$i\'),',
    ).join('\n');

    return '''
import 'package:flutter/material.dart';
import 'package:erp_scale_sim/features/common_feature/presentation/view/widgets/feature_field.dart';
import 'package:erp_scale_sim/features/common_feature/presentation/view/widgets/feature_grid.dart';
import '../controllers/bloc/screen_${screenId}_bloc.dart';

class Screen${screenId}View extends StatelessWidget {
  const Screen${screenId}View({super.key, required this.bloc});
  final Screen${screenId}Bloc bloc;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
$fields
          const FeatureGrid(rowCount: 5),
        ],
      ),
    );
  }
}
''';
  }

  String _moduleInitGetIt(String moduleId, String prefix, List<int> screenIds) {
    return '''
import 'package:erp_scale_sim/core/src/common_app_export.dart';
import '../../screens.dart';

class M${moduleId}InitGetIt {
  static void knowModule() {
    ModuleRegistry.register(_register);
  }

  static void _register() {
    registerModule${moduleId}Screens();
  }
}
''';
  }

  String _screensRegistry(String moduleId, List<int> screenIds) {
    final imports = screenIds
        .map((n) => "import 'src/features/screen_${padNum(n, 4)}/presentation/def/screen_${padNum(n, 4)}_def.dart';")
        .join('\n');
    final registrations = screenIds
        .map((n) => '  ScreenRegistry.register(Screen${padNum(n, 4)}Def());')
        .join('\n');

    return '''
import 'package:erp_scale_sim/core/src/common_app_export.dart';
$imports

void registerModule${moduleId}Screens() {
$registrations
}
''';
  }
}
