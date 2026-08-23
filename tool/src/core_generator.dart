import 'config.dart';
import 'templates.dart';
import 'utils.dart';

class CoreGenerator {
  CoreGenerator(this.config, this.root);

  final GenConfig config;
  final String root;
  final GenStats stats = GenStats();

  List<String> get units =>
      coreMixinUnits.take(config.mixins).toList(growable: false);

  void generate() {
    _generatePubspec();
    _generateCoreInfrastructure();
    _generateCommonFeature();
    _generateBarrelExports();
  }

  void _write(String relPath, String content) {
    writeFile('$root/$relPath', content);
    stats.addFile(content);
  }

  void _generatePubspec() {
    _write('pubspec.yaml', '''
name: erp_scale_sim
description: Core package for erp_scale_sim Flutter Web reproduction.
publish_to: 'none'
version: 1.0.0

environment:
  sdk: ^3.5.0

dependencies:
  flutter:
    sdk: flutter
  flutter_bloc: ^9.1.0
  bloc: ^9.0.0
  equatable: ^2.0.7
  get_it: ^8.0.3
  dartz: ^0.10.1
  reactive_forms: ^17.0.1
  collection: ^1.19.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0

flutter:
  uses-material-design: true
''');
  }

  void _generateCoreInfrastructure() {
    _write('lib/erp_scale_sim.dart', '''
export 'core/src/common_app_export.dart';
''');

    _write('lib/core/src/common_app_export.dart', _commonExport());

    _write('lib/core/types/either_types.dart', '''
export 'package:dartz/dartz.dart' show Either, Left, Right;

class Failure {
  const Failure(this.message);
  final String message;
}
''');

    _write('lib/core/types/loader_status.dart', '''
enum LoaderStatus { initial, loading, loaded, error }
''');

    _write('lib/core/enums/scr_mode.dart', '''
enum ScrMode { view, add, edit, delete, approve, post }
''');

    _write('lib/core/constants/app_constants.dart', '''
class AppConstants {
  static const appName = 'erp_scale_sim';
  static const defaultPageSize = 20;
}
''');

    _write('lib/core/helpers/either_helper.dart', '''
import '../types/either_types.dart';

typedef FoldCallback<T> = void Function(T value);
typedef FoldFailureCallback = void Function(Failure failure);

void safeFold<T>(
  Either<Failure, T> result,
  FoldCallback<T> onSuccess,
  FoldFailureCallback onFailure,
) {
  result.fold(onFailure, onSuccess);
}
''');

    _write('lib/core/shared_cubits/sub_state.dart', '''
import 'package:equatable/equatable.dart';

enum SubStateStatus { initial, loading, loaded, error }

class SubState<T> extends Equatable {
  const SubState._({required this.status, this.data, this.error});

  const SubState.initial() : this._(status: SubStateStatus.initial);
  const SubState.loading() : this._(status: SubStateStatus.loading);
  const SubState.loaded(T data) : this._(status: SubStateStatus.loaded, data: data);
  const SubState.error(String error) : this._(status: SubStateStatus.error, error: error);

  factory SubState.loadingFactory() => const SubState.loading();

  final SubStateStatus status;
  final T? data;
  final String? error;

  @override
  List<Object?> get props => [status, data, error];
}
''');

    _write('lib/core/shared_cubits/safe_bloc.dart', '''
import 'package:bloc/bloc.dart';

mixin SafeBloc<E, S> on Bloc<E, S> {
  @override
  void on<Evt extends E>(
    EventHandler<Evt, S> handler, {
    EventTransformer<Evt>? transformer,
  }) {
    super.on<Evt>(handler, transformer: transformer);
  }
}
''');

    _write('lib/core/network/api_service.dart', '''
class ApiService {
  Future<Map<String, dynamic>> get(String path) async {
    await Future<void>.delayed(Duration.zero);
    return {'path': path};
  }
}
''');

    _write('lib/core/network/config_reader.dart', '''
class ConfigReader {
  String get baseUrl => 'http://localhost';
}
''');

    _write('lib/core/network/token_service.dart', '''
class TokenService {
  String? token;
}
''');

    _write('lib/core/injection/get_it.dart', '''
import 'package:get_it/get_it.dart';

final getIt = GetIt.instance;
''');

    _write('lib/core/injection/core_injector.dart', '''
import '../network/api_service.dart';
import '../network/config_reader.dart';
import '../network/token_service.dart';
import 'get_it.dart';

class CoreInjector {
  static Future<void> initFirst() async {
    getIt.registerLazySingleton<ConfigReader>(() => ConfigReader());
    getIt.registerLazySingleton<ApiService>(() => ApiService());
    getIt.registerLazySingleton<TokenService>(() => TokenService());
    await Future<void>.delayed(Duration.zero);
  }
}
''');

    _write('lib/core/injection/inject_helper.dart', '''
import 'get_it.dart';

class InjectHelper {
  static T get<T extends Object>() => getIt.get<T>();
}
''');

    _write('lib/core/contracts/screens/screen_definition.dart', '''
import 'package:flutter/widgets.dart';

abstract class ScreenDefinition {
  String get screenId;
  String get moduleId;
  String get title;
  dynamic Function() get createBloc;
  Widget Function(BuildContext context, dynamic bloc) get buildView;
}
''');

    _write('lib/core/contracts/screens/screen_registry.dart', '''
import 'screen_definition.dart';

class ScreenRegistry {
  static final Map<String, ScreenDefinition> _screens = {};

  static void register(ScreenDefinition def) {
    _screens[def.screenId] = def;
  }

  static ScreenDefinition? get(String screenId) => _screens[screenId];

  static Iterable<ScreenDefinition> get all => _screens.values;

  static int get count => _screens.length;
}
''');

    _write('lib/core/contracts/screens/screen_caller.dart', '''
import '../../injection/inject_helper.dart';
import 'screen_registry.dart';

class ScreenCaller {
  static dynamic callCubit(String screenId) {
    final def = ScreenRegistry.get(screenId);
    if (def == null) throw StateError('Screen not found: \$screenId');
    return def.createBloc();
  }

  static T getService<T extends Object>() => InjectHelper.get<T>();
}
''');

    _write('lib/core/contracts/modules/module_registry.dart', '''
typedef ModuleInitCallback = void Function();

class ModuleRegistry {
  static final List<ModuleInitCallback> _inits = [];

  static void register(ModuleInitCallback init) => _inits.add(init);

  static Iterable<ModuleInitCallback> get all => _inits;
}
''');

    _write('lib/core/contracts/modules/module_caller.dart', '''
import 'module_registry.dart';
import '../screens/screen_registry.dart';

class ModuleCaller {
  static void callAllModules() {
    for (final init in ModuleRegistry.all) {
      init();
    }
  }

  static int get registeredScreenCount => ScreenRegistry.count;
}
''');

    _write('lib/core/contracts/vld/field_vld_definition.dart', '''
abstract class FieldVldDefinition {
  String get fieldKey;
  bool validate(dynamic value);
}
''');

    _write('lib/core/contracts/vld/validators_registry.dart', '''
import 'field_vld_definition.dart';

class ValidatorsRegistry {
  static final Map<String, FieldVldDefinition> _validators = {};

  static void register(FieldVldDefinition def) {
    _validators[def.fieldKey] = def;
  }

  static FieldVldDefinition? get(String key) => _validators[key];
}
''');

    _write('lib/core/contracts/vld/validators_caller.dart', '''
import 'validators_registry.dart';

class ValidatorsCaller {
  static bool validate(String key, dynamic value) {
    return ValidatorsRegistry.get(key)?.validate(value) ?? true;
  }
}
''');

    _write('lib/core/contracts/link_keys/link_key_definition.dart', '''
abstract class LinkKeyDefinition {
  String get key;
  String resolve(Map<String, dynamic> context);
}
''');

    _write('lib/core/contracts/link_keys/link_key_registry.dart', '''
import 'link_key_definition.dart';

class LinkKeyRegistry {
  static final Map<String, LinkKeyDefinition> _keys = {};

  static void register(LinkKeyDefinition def) => _keys[def.key] = def;
}
''');

    _write('lib/core/contracts/link_keys/link_key_caller.dart', '''
import 'link_key_definition.dart';

class LinkKeyCaller {
  static final Map<String, LinkKeyDefinition> _keys = {};

  static void register(LinkKeyDefinition def) => _keys[def.key] = def;

  static String? resolve(String key, Map<String, dynamic> context) {
    return _keys[key]?.resolve(context);
  }
}
''');

    _write('lib/core/reactive_forms/form_session.dart', '''
class FormSession {
  final Map<String, dynamic> values = {};
  void setValue(String key, dynamic value) => values[key] = value;
}
''');

    _write('lib/core/grid/grid_state_manager.dart', '''
class GridStateManager {
  final List<Map<String, dynamic>> rows = [];
  int pageNo = 1;
  int pageSize = 20;
}
''');
  }

  String _commonExport() {
    return '''
export 'dart:async';

export '../types/either_types.dart';
export '../types/loader_status.dart';
export '../enums/scr_mode.dart';
export '../constants/app_constants.dart';
export '../helpers/either_helper.dart';
export '../shared_cubits/sub_state.dart';
export '../shared_cubits/safe_bloc.dart';
export '../network/api_service.dart';
export '../network/config_reader.dart';
export '../network/token_service.dart';
export '../injection/get_it.dart';
export '../injection/core_injector.dart';
export '../injection/inject_helper.dart';
export '../contracts/screens/screen_definition.dart';
export '../contracts/screens/screen_registry.dart';
export '../contracts/screens/screen_caller.dart';
export '../contracts/modules/module_registry.dart';
export '../contracts/modules/module_caller.dart';
export '../contracts/vld/field_vld_definition.dart';
export '../contracts/vld/validators_registry.dart';
export '../contracts/vld/validators_caller.dart';
export '../contracts/link_keys/link_key_definition.dart';
export '../contracts/link_keys/link_key_registry.dart';
export '../contracts/link_keys/link_key_caller.dart';
export '../reactive_forms/form_session.dart';
export '../grid/grid_state_manager.dart';

export 'package:flutter/material.dart';
export 'package:flutter_bloc/flutter_bloc.dart';
export 'package:bloc/bloc.dart';
export 'package:equatable/equatable.dart';
export 'package:reactive_forms/reactive_forms.dart';
''';
  }

  void _generateCommonFeature() {
    // Events
    for (final unit in units) {
      _write(
        'lib/features/common_feature/presentation/controllers/events/${eventDir(unit).split('/').last}/${unit}_event.dart',
        generateEventFile(config, unit),
      );
    }

    _write('lib/features/common_feature/presentation/controllers/events/feature_event.dart', '''
import 'package:equatable/equatable.dart';

abstract class FeatureEvent extends Equatable {
  const FeatureEvent();
  @override
  List<Object?> get props => [];
}
''');

    // Contracts
    for (final unit in units) {
      _write(
        'lib/features/common_feature/presentation/controllers/contracts/${unit}_contract.dart',
        generateContractFile(config, unit),
      );
    }

    // Entities + use cases
    for (final unit in units) {
      _write(
        'lib/features/common_feature/domain/entities/${unit}_ent.dart',
        generateEntityFile(unit),
      );
      _write(
        'lib/features/common_feature/domain/use_cases/${unit}_use_case.dart',
        generateUseCaseFile(unit),
      );
    }

    _write('lib/features/common_feature/domain/use_cases/feature_use_cases.dart', '''
${units.map((u) => "import '${u}_use_case.dart';").join('\n')}

class FeatureUseCases {
  FeatureUseCases({
${units.map((u) => '    required this.${toCamel(u)}UseCase,').join('\n')}
  });

${units.map((u) => '  final ${useCaseClassName(u)} ${toCamel(u)}UseCase;').join('\n')}
}
''');

    // Mixins
    if (config.isMixin || config.isMixinShared || config.isMixinWithoutGeneric) {
      for (var i = 0; i < units.length; i++) {
        _write(
          'lib/features/common_feature/presentation/controllers/${mixinDir(units[i])}/${units[i]}_mixin.dart',
          generateMixinFile(config, units[i], i, units),
        );
      }
    } else if (config.isOneMixin) {
      _write(
        'lib/features/common_feature/presentation/controllers/mixins/feature_mixin.dart',
        _generateOneMixin(),
      );
    }

    // State
    _write('lib/features/common_feature/presentation/controllers/state/feature_state.dart', _featureState());
    _write('lib/features/common_feature/presentation/controllers/state/feature_state_props.dart', _featureStateProps());

    // Bloc base chain
    _write('lib/features/common_feature/presentation/controllers/bloc/feature_bloc_base.dart', _featureBlocBase());
    _write('lib/features/common_feature/presentation/controllers/bloc/feature_contract_bloc.dart', _featureContractBloc());

    if (config.isComposition) {
      _write('lib/features/common_feature/presentation/controllers/bloc/feature_capability.dart', _featureCapability());

      // Capabilities (Composition Objects)
      for (final unit in units) {
        _write(
          'lib/features/common_feature/presentation/controllers/capabilities/${unit}_capability.dart',
          _generateCapability(config, unit),
        );
      }
    }

    _write('lib/features/common_feature/presentation/controllers/bloc/feature_bloc.dart', _featureBloc());

    // Data layer
    _write('lib/features/common_feature/data/datasources/feature_remote_data_source.dart', '''
class FeatureRemoteDataSource {
  Future<Map<String, dynamic>> fetch(String screenId) async => {'screenId': screenId};
}
''');

    _write('lib/features/common_feature/data/repos/feature_repo.dart', '''
import '../datasources/feature_remote_data_source.dart';

class FeatureRepo {
  FeatureRepo(this.remote);
  final FeatureRemoteDataSource remote;
}
''');

    _write('lib/features/common_feature/domain/contracts/feature_contract.dart', '''
abstract class FeatureContract {
  String get screenId;
}
''');

    _write('lib/features/common_feature/injection/common_feature_injection.dart', _commonFeatureInjection());

    // Template view/def
    _write('lib/features/common_feature/presentation/template/common_feature_def.dart', _commonFeatureDef());
    _write('lib/features/common_feature/presentation/template/common_feature_view.dart', _commonFeatureView());
    _write('lib/features/common_feature/presentation/view/widgets/feature_scaffold.dart', _featureScaffold());
    _write('lib/features/common_feature/presentation/view/widgets/feature_field.dart', _featureField());
    _write('lib/features/common_feature/presentation/view/widgets/feature_grid.dart', _featureGrid());
  }

  String _featureCapability() {
    return '''
import 'feature_bloc.dart';
import '../state/feature_state.dart';

abstract class FeatureCapability<T extends FeatureState> {
  String get unitId;
  void registerHandlers(FeatureBloc<T> bloc);
}
''';
  }

  String _generateCapability(GenConfig config, String unit) {
    final cap = capabilityClassName(unit);
    final contract = mixinContractName(unit);
    final stateCls = '_${toPascal(unit)}CapabilityState';
    final eventCls = eventClassName(unit);
    final camel = toCamel(unit);

    final buf = StringBuffer();
    buf.writeln("import 'package:erp_scale_sim/core/src/common_app_export.dart';");
    buf.writeln("import '../bloc/feature_capability.dart';");
    buf.writeln("import '../bloc/feature_bloc.dart';");
    buf.writeln("import '../state/feature_state.dart';");
    buf.writeln("import '../contracts/${unit}_contract.dart';");
    buf.writeln("import '../../../domain/entities/${unit}_ent.dart';");
    buf.writeln("import '../../../domain/use_cases/${unit}_use_case.dart';");
    buf.writeln("import '../events/${eventDir(unit).split('/').last}/${unit}_event.dart';");
    buf.writeln();
    buf.writeln('class $stateCls {');
    buf.writeln('  int loadCount = 0;');
    buf.writeln('  int submitCount = 0;');
    buf.writeln('  final Map<String, dynamic> cache = {};');
    buf.writeln('  final Set<String> pendingKeys = {};');
    buf.writeln('  Completer<void>? inFlight;');
    buf.writeln('  ScrMode mode = ScrMode.view;');
    buf.writeln('}');
    buf.writeln();
    buf.writeln('class $cap<T extends FeatureState> implements FeatureCapability<T>, $contract {');
    buf.writeln('  $cap(this._host);');
    buf.writeln('  final FeatureBloc<T> _host;');
    buf.writeln('  final $stateCls _state = $stateCls();');
    buf.writeln();
    buf.writeln('  @override String get unitId => \'$unit\';');
    buf.writeln();
    buf.writeln('  /// Direct access to host FeatureBloc');
    buf.writeln('  FeatureBloc<T> get host => _host;');
    buf.writeln();
    buf.writeln('  /// Convenient access to any sibling capability');
    buf.writeln('  C sibling<C extends FeatureCapability<T>>() => _host.getCapability<C>();');
    buf.writeln();
    buf.writeln('  @override');
    buf.writeln('  void registerHandlers(FeatureBloc<T> bloc) {');
    buf.writeln('    bloc.on<$eventCls>((event, emit) async {');
    buf.writeln('      switch (event) {');
    for (var m = 0; m < config.methods; m++) {
      final opName = m == 0 ? 'Load' : m == 1 ? 'Submit' : m == 2 ? 'Refresh' : m == 3 ? 'Reset' : 'Op$m';
      buf.writeln('        case ${toPascal(unit)}${opName}Event():');
      buf.writeln('          await _handle$opName(event);');
    }
    buf.writeln('      }');
    buf.writeln('    });');
    buf.writeln('  }');
    buf.writeln();

    buf.writeln('  @override');
    buf.writeln('  SubState<${toPascal(unit)}Ent>? get ${camel}OnLoadState => _host.state.stateProps.${camel}OnLoadState;');
    buf.writeln();

    for (var m = 0; m < config.methods; m++) {
      if (m == 0) {
        buf.writeln('  @override Future<void> load${toPascal(unit)}Screen({String? docSrl, bool force = false}) => _host.dispatchWithCompleter(${toPascal(unit)}LoadEvent(docSrl: docSrl, force: force));');
      } else if (m == 1) {
        buf.writeln('  @override Future<void> submit${toPascal(unit)}({int payload = 0, Map<String, dynamic>? currentPk}) => _host.dispatchWithCompleter(${toPascal(unit)}SubmitEvent(payload: payload, currentPk: currentPk));');
      } else if (m == 2) {
        buf.writeln('  @override Future<bool> refresh${toPascal(unit)}({int pgNo = 1, int pgSz = 20}) async { final c = Completer<bool>(); _host.add(${toPascal(unit)}RefreshEvent(pgNo: pgNo, pgSz: pgSz, completer: c)); return c.future; }');
      } else if (m == 3) {
        buf.writeln('  @override void reset${toPascal(unit)}() => _host.add(const ${toPascal(unit)}ResetEvent());');
      } else {
        buf.writeln('  @override Future<void> execute${toPascal(unit)}Op$m({Map<String, dynamic>? params}) => _host.dispatchWithCompleter(${toPascal(unit)}Op${m}Event(params: params));');
      }
    }
    buf.writeln();

    for (var m = 0; m < config.methods; m++) {
      final opName = m == 0 ? 'Load' : m == 1 ? 'Submit' : m == 2 ? 'Refresh' : m == 3 ? 'Reset' : 'Op$m';
      buf.writeln('  Future<void> _handle$opName(${toPascal(unit)}${opName}Event event) async {');
      buf.writeln('    _state.loadCount++;');
      buf.writeln('    _host.emitLoading(${camel}OnLoadState: const SubState.loading());');
      buf.writeln('    final result = await _host.featureUseCases.${camel}UseCase.call(${toPascal(unit)}Params(screenId: _host.screenId, payload: event.hashCode));');
      buf.writeln('    _host.safeFold(result, (data) { _state.cache[\'$unit\'] = data.toJson(); _host.emitLoaded(${camel}OnLoadState: SubState.loaded(data)); }, (f) { _host.emitError(${camel}OnLoadState: SubState.error(f.message)); });');
      if (m == 2) buf.writeln('    event.completer?.complete(true);');
      buf.writeln('  }');
      buf.writeln();
    }

    for (var p = 0; p < 12; p++) {
      buf.writeln('  bool _${camel}Check$p(ScrMode mode) => _state.mode == mode;');
    }
    buf.writeln();
    buf.writeln('  bool check${toPascal(unit)}Mode(ScrMode mode) =>');
    final checkLines = List.generate(12, (p) => '      _${camel}Check$p(mode)').join(' ||\n');
    buf.writeln('$checkLines;');

    buf.writeln('}');
    return buf.toString();
  }

  String _featureStateProps() {
    final fields = units.map((u) {
      final camel = toCamel(u);
      return '    final SubState<${toPascal(u)}Ent>? ${camel}OnLoadState;';
    }).join('\n');

    final ctorParams = units.map((u) {
      final camel = toCamel(u);
      return '    this.${camel}OnLoadState,';
    }).join('\n');

    final copyParams = units.map((u) {
      final camel = toCamel(u);
      return '      ${camel}OnLoadState: ${camel}OnLoadState ?? this.${camel}OnLoadState,';
    }).join('\n');

    final propsList = units.map((u) => '    ${toCamel(u)}OnLoadState,').join('\n');

    return '''
import 'package:equatable/equatable.dart';
import 'package:erp_scale_sim/core/shared_cubits/sub_state.dart';
${units.map((u) => "import '../../../domain/entities/${u}_ent.dart';").join('\n')}

class FeatureStateProps extends Equatable {
  const FeatureStateProps({
$ctorParams
  });

$fields

  FeatureStateProps copyWith({
${units.map((u) => '    SubState<${toPascal(u)}Ent>? ${toCamel(u)}OnLoadState,').join('\n')}
  }) {
    return FeatureStateProps(
$copyParams
    );
  }

  @override
  List<Object?> get props => [
$propsList
  ];
}
''';
  }

  String _featureState() {
    return '''
import 'package:equatable/equatable.dart';
import 'package:erp_scale_sim/core/types/loader_status.dart';
import 'feature_state_props.dart';

class FeatureState extends Equatable {
  const FeatureState({
    this.loaderStatus = LoaderStatus.initial,
    this.stateProps = const FeatureStateProps(),
    this.screenId = '',
  });

  final LoaderStatus loaderStatus;
  final FeatureStateProps stateProps;
  final String screenId;

  FeatureState copyWith({
    LoaderStatus? loaderStatus,
    FeatureStateProps? stateProps,
    String? screenId,
  }) {
    return FeatureState(
      loaderStatus: loaderStatus ?? this.loaderStatus,
      stateProps: stateProps ?? this.stateProps,
      screenId: screenId ?? this.screenId,
    );
  }

  @override
  List<Object?> get props => [loaderStatus, stateProps, screenId];
}
''';
  }

  String _featureBlocBase() {
    return '''
import 'package:erp_scale_sim/core/src/common_app_export.dart';
import '../events/feature_event.dart';
import '../state/feature_state.dart';
import '../../../domain/use_cases/feature_use_cases.dart';

abstract class FeatureBlocBase<T extends FeatureState> extends Bloc<FeatureEvent, T> with SafeBloc {
  FeatureBlocBase(super.initialState, {required this.featureUseCases, required this.screenId});

  final FeatureUseCases featureUseCases;
  final String screenId;

  Future<void> dispatchWithCompleter<E extends FeatureEvent>(E event) async {
    add(event);
  }

  void registerFeatureEventHandlers() {}
}
''';
  }

  String _featureContractBloc() {
    if (config.isOneMixin) {
      final methodSignatures = units.map((u) {
        final buf = StringBuffer();
        final camel = toCamel(u);
        final pascal = toPascal(u);
        buf.writeln('  SubState<${pascal}Ent>? get ${camel}OnLoadState;');
        for (var m = 0; m < config.methods; m++) {
          if (m == 0) {
            buf.writeln('  Future<void> load${pascal}Screen({String? docSrl, bool force = false});');
          } else if (m == 1) {
            buf.writeln('  Future<void> submit$pascal({int payload = 0, Map<String, dynamic>? currentPk});');
          } else if (m == 2) {
            buf.writeln('  Future<bool> refresh$pascal({int pgNo = 1, int pgSz = 20});');
          } else if (m == 3) {
            buf.writeln('  void reset$pascal();');
          } else {
            buf.writeln('  Future<void> execute${pascal}Op$m({Map<String, dynamic>? params});');
          }
        }
        return buf.toString();
      }).join('\n');

      return '''
import 'package:erp_scale_sim/core/src/common_app_export.dart';
import '../../../domain/use_cases/feature_use_cases.dart';
import '../state/feature_state.dart';
${units.map((u) => "import '../../../domain/entities/${u}_ent.dart';").join('\n')}

abstract class IFeatureMixin {
$methodSignatures
}

abstract class IFeatureBloc<T extends FeatureState> implements IFeatureMixin {
  FeatureUseCases get featureUseCases;
  String get screenId;
  T get state;
}
''';
    }

    final contracts = joinIndented(
      units.map((u) => mixinContractName(u)).toList(),
      indent: '    ',
    );
    return '''
import '../../../domain/use_cases/feature_use_cases.dart';
import '../state/feature_state.dart';
${units.map((u) => "import '../contracts/${u}_contract.dart';").join('\n')}

abstract class IFeatureBloc<T extends FeatureState> implements
$contracts {
  FeatureUseCases get featureUseCases;
  String get screenId;
  T get state;
}
''';
  }

  String _generateOneMixin() {
    final stateClasses = units.map((u) {
      final stateCls = '_${toPascal(u)}MixinState';
      return '''
class $stateCls {
  int loadCount = 0;
  int submitCount = 0;
  final Map<String, dynamic> cache = {};
  final Set<String> pendingKeys = {};
  Completer<void>? inFlight;
  ScrMode mode = ScrMode.view;
}''';
    }).join('\n\n');

    final stateInstances = units.map((u) {
      return '  final _${toPascal(u)}MixinState _${toCamel(u)}State = _${toPascal(u)}MixinState();';
    }).join('\n');

    final eventRegistrations = units.map((u) {
      final eventCls = eventClassName(u);
      final buf = StringBuffer();
      buf.writeln('    on<$eventCls>((event, emit) async {');
      buf.writeln('      switch (event) {');
      for (var m = 0; m < config.methods; m++) {
        final opName = m == 0 ? 'Load' : m == 1 ? 'Submit' : m == 2 ? 'Refresh' : m == 3 ? 'Reset' : 'Op$m';
        buf.writeln('        case ${toPascal(u)}${opName}Event():');
        buf.writeln('          await _handle${toPascal(u)}$opName(event);');
      }
      buf.writeln('      }');
      buf.writeln('    });');
      return buf.toString();
    }).join('\n');

    final statePropsGetters = units.map((u) {
      final camel = toCamel(u);
      return '  @override\n  SubState<${toPascal(u)}Ent>? get ${camel}OnLoadState => state.stateProps.${camel}OnLoadState;';
    }).join('\n\n');

    final methodImpls = units.map((u) {
      final buf = StringBuffer();
      final camel = toCamel(u);
      final pascal = toPascal(u);
      for (var m = 0; m < config.methods; m++) {
        if (m == 0) {
          buf.writeln('  @override Future<void> load${pascal}Screen({String? docSrl, bool force = false}) => dispatchWithCompleter(${pascal}LoadEvent(docSrl: docSrl, force: force));');
        } else if (m == 1) {
          buf.writeln('  @override Future<void> submit$pascal({int payload = 0, Map<String, dynamic>? currentPk}) => dispatchWithCompleter(${pascal}SubmitEvent(payload: payload, currentPk: currentPk));');
        } else if (m == 2) {
          buf.writeln('  @override Future<bool> refresh$pascal({int pgNo = 1, int pgSz = 20}) async { final c = Completer<bool>(); add(${pascal}RefreshEvent(pgNo: pgNo, pgSz: pgSz, completer: c)); return c.future; }');
        } else if (m == 3) {
          buf.writeln('  @override void reset$pascal() => add(const ${pascal}ResetEvent());');
        } else {
          buf.writeln('  @override Future<void> execute${pascal}Op$m({Map<String, dynamic>? params}) => dispatchWithCompleter(${pascal}Op${m}Event(params: params));');
        }
      }

      buf.writeln();
      for (var m = 0; m < config.methods; m++) {
        final opName = m == 0 ? 'Load' : m == 1 ? 'Submit' : m == 2 ? 'Refresh' : m == 3 ? 'Reset' : 'Op$m';
        if (m == 3) {
          buf.writeln('  Future<void> _handle${pascal}Reset(${pascal}ResetEvent event) async {');
          buf.writeln('    _${camel}State.loadCount = 0;');
          buf.writeln('    _${camel}State.submitCount = 0;');
          buf.writeln('    _${camel}State.cache.clear();');
          buf.writeln('    _${camel}State.pendingKeys.clear();');
          buf.writeln('    emit(state.copyWith(');
          buf.writeln('      stateProps: state.stateProps.copyWith(${camel}OnLoadState: null),');
          buf.writeln('    ) as T);');
          buf.writeln('  }');
        } else {
          buf.writeln('  Future<void> _handle$pascal$opName($pascal${opName}Event event) async {');
          buf.writeln('    _${camel}State.loadCount++;');
          buf.writeln('    emit(state.copyWith(');
          buf.writeln('      loaderStatus: LoaderStatus.loading,');
          buf.writeln('      stateProps: state.stateProps.copyWith(${camel}OnLoadState: const SubState.loading()),');
          buf.writeln('    ) as T);');
          buf.writeln('    final result = await featureUseCases.${camel}UseCase.call(${pascal}Params(screenId: screenId, payload: event.hashCode));');
          buf.writeln('    safeFold(result, (data) {');
          buf.writeln('      _${camel}State.cache[\'$u\'] = data.toJson();');
          buf.writeln('      emit(state.copyWith(');
          buf.writeln('        loaderStatus: LoaderStatus.loaded,');
          buf.writeln('        stateProps: state.stateProps.copyWith(${camel}OnLoadState: SubState.loaded(data)),');
          buf.writeln('      ) as T);');
          buf.writeln('    }, (f) {');
          buf.writeln('      emit(state.copyWith(');
          buf.writeln('        loaderStatus: LoaderStatus.error,');
          buf.writeln('        stateProps: state.stateProps.copyWith(${camel}OnLoadState: SubState.error(f.message)),');
          buf.writeln('      ) as T);');
          buf.writeln('    });');
          if (m == 2) buf.writeln('    event.completer?.complete(true);');
          buf.writeln('  }');
        }
        buf.writeln();
      }

      for (var p = 0; p < 12; p++) {
        buf.writeln('  bool _${camel}Check$p(ScrMode mode) => _${camel}State.mode == mode;');
      }
      buf.writeln();
      buf.writeln('  bool check${pascal}Mode(ScrMode mode) =>');
      final checkLines = List.generate(12, (p) => '      _${camel}Check$p(mode)').join(' ||\n');
      buf.writeln('$checkLines;');

      return buf.toString();
    }).join('\n\n');

    return '''
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'package:erp_scale_sim/core/src/common_app_export.dart';
import '../events/feature_event.dart';
import '../bloc/feature_bloc_base.dart';
import '../bloc/feature_contract_bloc.dart';
import '../state/feature_state.dart';
${units.map((u) => "import '../../../domain/entities/${u}_ent.dart';").join('\n')}
${units.map((u) => "import '../../../domain/use_cases/${u}_use_case.dart';").join('\n')}
${units.map((u) => "import '../events/${eventDir(u).split('/').last}/${u}_event.dart';").join('\n')}

$stateClasses

mixin FeatureMixin<T extends FeatureState> on FeatureBlocBase<T>, Bloc<FeatureEvent, T>
    implements IFeatureBloc<T> {
$stateInstances

  void registerFeatureMixinHandlers() {
$eventRegistrations
  }

$statePropsGetters

$methodImpls
}
''';
  }

  String _featureBloc() {
    if (config.isOneMixin) {
      return '''
import 'feature_bloc_base.dart';
import 'feature_contract_bloc.dart';
import '../state/feature_state.dart';
import '../mixins/feature_mixin.dart';

class FeatureBloc<T extends FeatureState> extends FeatureBlocBase<T>
    with FeatureMixin<T>
    implements IFeatureBloc<T> {
  FeatureBloc({
    required super.featureUseCases,
    required super.screenId,
    required T initialState,
  }) : super(initialState) {
    registerFeatureEventHandlers();
  }

  @override
  void registerFeatureEventHandlers() {
    super.registerFeatureEventHandlers();
    registerFeatureMixinHandlers();
  }
}
''';
    }

    if (config.isMixinWithoutGeneric) {
      final mixinLines = units.map((u) => mixinClassName(u)).toList();
      final withClause = joinIndented(mixinLines);
      final registrations = units.map((u) => '    register${toPascal(u)}MixinHandlers();').join('\n');

      return '''
import 'feature_bloc_base.dart';
import 'feature_contract_bloc.dart';
import '../state/feature_state.dart';
${units.map((u) => "import '../${mixinDir(u)}/${u}_mixin.dart';").join('\n')}

class FeatureBloc extends FeatureBlocBase<FeatureState>
    with
$withClause
    implements IFeatureBloc<FeatureState> {
  FeatureBloc({
    required super.featureUseCases,
    required super.screenId,
    required FeatureState initialState,
  }) : super(initialState) {
    registerFeatureEventHandlers();
  }

  @override
  void registerFeatureEventHandlers() {
    super.registerFeatureEventHandlers();
$registrations
  }
}
''';
    }

    if (config.isMixin || config.isMixinShared) {
      final mixinLines = units.map((u) {
        if (nonGenericMixins.contains(u)) return mixinClassName(u);
        return '${mixinClassName(u)}<T>';
      }).toList();
      final withClause = joinIndented(mixinLines);
      final registrations = units.map((u) => '    register${toPascal(u)}MixinHandlers();').join('\n');

      return '''
import 'feature_bloc_base.dart';
import 'feature_contract_bloc.dart';
import '../state/feature_state.dart';
${units.map((u) => "import '../${mixinDir(u)}/${u}_mixin.dart';").join('\n')}

class FeatureBloc<T extends FeatureState> extends FeatureBlocBase<T>
    with
$withClause
    implements IFeatureBloc<T> {
  FeatureBloc({
    required super.featureUseCases,
    required super.screenId,
    required T initialState,
  }) : super(initialState) {
    registerFeatureEventHandlers();
  }

  @override
  void registerFeatureEventHandlers() {
    super.registerFeatureEventHandlers();
$registrations
  }
}
''';
    }

    final capFields = units.map((u) {
      return '  late final ${capabilityClassName(u)}<T> ${toCamel(u)}Capability;';
    }).join('\n');

    final capList = units.map((u) {
      return '      ${toCamel(u)}Capability = ${capabilityClassName(u)}<T>(this),';
    }).join('\n');

    final emitFields = units.map((u) {
      final camel = toCamel(u);
      return '    SubState<${toPascal(u)}Ent>? ${camel}OnLoadState,';
    }).join('\n');

    final copyFields = units.map((u) {
      final camel = toCamel(u);
      return '        ${camel}OnLoadState: ${camel}OnLoadState ?? state.stateProps.${camel}OnLoadState,';
    }).join('\n');

    final statePropsDelegates = units.map((u) {
      final camel = toCamel(u);
      return '  @override\n  SubState<${toPascal(u)}Ent>? get ${camel}OnLoadState => ${camel}Capability.${camel}OnLoadState;';
    }).join('\n\n');

    final methodDelegates = units.map((u) {
      final buf = StringBuffer();
      for (var m = 0; m < config.methods; m++) {
        if (m == 0) {
          buf.writeln('  @override\n  Future<void> load${toPascal(u)}Screen({String? docSrl, bool force = false}) =>\n      ${toCamel(u)}Capability.load${toPascal(u)}Screen(docSrl: docSrl, force: force);');
        } else if (m == 1) {
          buf.writeln('  @override\n  Future<void> submit${toPascal(u)}({int payload = 0, Map<String, dynamic>? currentPk}) =>\n      ${toCamel(u)}Capability.submit${toPascal(u)}(payload: payload, currentPk: currentPk);');
        } else if (m == 2) {
          buf.writeln('  @override\n  Future<bool> refresh${toPascal(u)}({int pgNo = 1, int pgSz = 20}) =>\n      ${toCamel(u)}Capability.refresh${toPascal(u)}(pgNo: pgNo, pgSz: pgSz);');
        } else if (m == 3) {
          buf.writeln('  @override\n  void reset${toPascal(u)}() =>\n      ${toCamel(u)}Capability.reset${toPascal(u)}();');
        } else {
          buf.writeln('  @override\n  Future<void> execute${toPascal(u)}Op$m({Map<String, dynamic>? params}) =>\n      ${toCamel(u)}Capability.execute${toPascal(u)}Op$m(params: params);');
        }
      }
      return buf.toString();
    }).join('\n');

    return '''
import 'package:erp_scale_sim/core/src/common_app_export.dart';
import 'feature_bloc_base.dart';
import 'feature_contract_bloc.dart';
import 'feature_capability.dart';
import '../state/feature_state.dart';
${units.map((u) => "import '../../../domain/entities/${u}_ent.dart';").join('\n')}
${units.map((u) => "import '../capabilities/${u}_capability.dart';").join('\n')}

class FeatureBloc<T extends FeatureState> extends FeatureBlocBase<T>
    implements IFeatureBloc<T> {
  FeatureBloc({
    required super.featureUseCases,
    required super.screenId,
    required T initialState,
  }) : super(initialState) {
    _initCapabilities();
    registerFeatureEventHandlers();
  }

$capFields

  late final Map<Type, FeatureCapability<T>> _capabilityTypeMap;
  late final Map<String, FeatureCapability<T>> _capabilityIdMap;

  void _initCapabilities() {
    final allCaps = <FeatureCapability<T>>[
$capList
    ];
    _capabilityTypeMap = {
      for (final cap in allCaps) cap.runtimeType: cap,
    };
    _capabilityIdMap = {
      for (final cap in allCaps) cap.unitId: cap,
    };
    for (final cap in allCaps) {
      cap.registerHandlers(this);
    }
  }

  /// Type-safe dynamic capability lookup:
  C getCapability<C extends FeatureCapability<T>>() {
    final cap = _capabilityTypeMap[C];
    if (cap == null) throw StateError('Capability not found for type: \$C');
    return cap as C;
  }

  /// Lookup capability by string ID:
  FeatureCapability<T>? findCapabilityById(String unitId) => _capabilityIdMap[unitId];

  // Full BloC state emission operations:
  void emitLoading({
$emitFields
  }) {
    // ignore: invalid_use_of_visible_for_testing_member
    emit(state.copyWith(
      loaderStatus: LoaderStatus.loading,
      stateProps: state.stateProps.copyWith(
$copyFields
      ),
    ) as T);
  }

  void emitLoaded({
$emitFields
  }) {
    // ignore: invalid_use_of_visible_for_testing_member
    emit(state.copyWith(
      loaderStatus: LoaderStatus.loaded,
      stateProps: state.stateProps.copyWith(
$copyFields
      ),
    ) as T);
  }

  void emitError({
$emitFields
  }) {
    // ignore: invalid_use_of_visible_for_testing_member
    emit(state.copyWith(
      loaderStatus: LoaderStatus.error,
      stateProps: state.stateProps.copyWith(
$copyFields
      ),
    ) as T);
  }

  void safeFold<R>(Either<Failure, R> result, void Function(R) onSuccess, void Function(Failure) onFailure) {
    result.fold(onFailure, onSuccess);
  }

  // --- Contract State Delegations ---
$statePropsDelegates

  // --- Contract Method Delegations ---
$methodDelegates
}
''';
  }

  String _commonFeatureInjection() {
    final useCaseRegs = units.map((u) => '    getIt.registerLazySingleton<${useCaseClassName(u)}>(() => ${useCaseClassName(u)}());').join('\n');
    final useCaseParams = units.map((u) => '      ${toCamel(u)}UseCase: getIt<${useCaseClassName(u)}>(),').join('\n');

    return '''
import 'package:erp_scale_sim/core/injection/get_it.dart';
import '../domain/use_cases/feature_use_cases.dart';
${units.map((u) => "import '../domain/use_cases/${u}_use_case.dart';").join('\n')}
import '../data/datasources/feature_remote_data_source.dart';
import '../data/repos/feature_repo.dart';

class CommonFeatureInjection {
  static bool _registered = false;

  static void register() {
    if (_registered) return;
    _registered = true;

    getIt.registerLazySingleton<FeatureRemoteDataSource>(() => FeatureRemoteDataSource());
    getIt.registerLazySingleton<FeatureRepo>(() => FeatureRepo(getIt()));
$useCaseRegs
    getIt.registerLazySingleton<FeatureUseCases>(() => FeatureUseCases(
$useCaseParams
    ));
  }
}
''';
  }

  String _commonFeatureDef() {
    return '''
class CommonFeatureDef {
  static String screenTitle(String id) => 'Screen \$id';
}
''';
  }

  String _commonFeatureView() {
    return '''
import 'package:erp_scale_sim/core/src/common_app_export.dart';
import '../view/widgets/feature_scaffold.dart';

class CommonFeatureView extends StatelessWidget {
  const CommonFeatureView({super.key, required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FeatureScaffold(title: title, body: child);
  }
}
''';
  }

  String _featureScaffold() {
    return '''
import 'package:flutter/material.dart';

class FeatureScaffold extends StatelessWidget {
  const FeatureScaffold({super.key, required this.title, required this.body});
  final String title;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: body,
    );
  }
}
''';
  }

  String _featureField() {
    return '''
import 'package:flutter/material.dart';

class FeatureField extends StatelessWidget {
  const FeatureField({super.key, required this.label, this.value = ''});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: TextFormField(
        initialValue: value,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ),
    );
  }
}
''';
  }

  String _featureGrid() {
    return '''
import 'package:flutter/material.dart';

class FeatureGrid extends StatelessWidget {
  const FeatureGrid({super.key, required this.rowCount});
  final int rowCount;

  @override
  Widget build(BuildContext context) {
    return DataTable(
      columns: const [
        DataColumn(label: Text('Col A')),
        DataColumn(label: Text('Col B')),
        DataColumn(label: Text('Col C')),
      ],
      rows: List.generate(rowCount, (i) => DataRow(cells: [
        DataCell(Text('A\$i')),
        DataCell(Text('B\$i')),
        DataCell(Text('C\$i')),
      ])),
    );
  }
}
''';
  }

  void _generateBarrelExports() {
    final extraExport = config.isComposition
        ? "export 'presentation/controllers/bloc/feature_capability.dart';"
        : config.isOneMixin
            ? "export 'presentation/controllers/mixins/feature_mixin.dart';"
            : "";
    _write('lib/features/common_feature/common_feature.dart', '''
export 'domain/use_cases/feature_use_cases.dart';
export 'domain/entities/load_scr_ent.dart';
export 'data/datasources/feature_remote_data_source.dart';
export 'data/repos/feature_repo.dart';
export 'presentation/controllers/bloc/feature_bloc.dart';
$extraExport
export 'presentation/controllers/state/feature_state.dart';
export 'injection/common_feature_injection.dart';
''');
  }
}
