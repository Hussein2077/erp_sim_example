import 'config.dart';

/// Generates contract file for a unit.
String generateContractFile(GenConfig config, String unit) {
  final contract = mixinContractName(unit);
  final camel = toCamel(unit);
  final buf = StringBuffer();
  buf.writeln("import 'package:erp_scale_sim/core/src/common_app_export.dart';");
  buf.writeln("import '../../../domain/entities/${unit}_ent.dart';");
  buf.writeln();
  buf.writeln('abstract class $contract {');
  for (var m = 0; m < config.methods; m++) {
    if (m == 0) {
      buf.writeln('  SubState<${toPascal(unit)}Ent>? get ${camel}OnLoadState;');
      buf.writeln('  Future<void> load${toPascal(unit)}Screen({String? docSrl, bool force = false});');
    } else if (m == 1) {
      buf.writeln('  Future<void> submit${toPascal(unit)}({int payload = 0, Map<String, dynamic>? currentPk});');
    } else if (m == 2) {
      buf.writeln('  Future<bool> refresh${toPascal(unit)}({int pgNo = 1, int pgSz = 20});');
    } else if (m == 3) {
      buf.writeln('  void reset${toPascal(unit)}();');
    } else {
      buf.writeln('  Future<void> execute${toPascal(unit)}Op$m({Map<String, dynamic>? params});');
    }
  }
  buf.writeln('}');
  return buf.toString();
}

String generateMixinFile(GenConfig config, String unit, int index, List<String> units) {
  final cls = mixinClassName(unit);
  final stateCls = mixinStateClass(unit);
  final eventCls = eventClassName(unit);
  final camel = toCamel(unit);
  final isGeneric = !config.isMixinWithoutGeneric && !nonGenericMixins.contains(unit);
  final typeParam = isGeneric ? '<T extends FeatureState>' : '';
  final stateType = isGeneric ? 'T' : 'FeatureState';
  final onClause = _mixinOnClause(config, unit, index, units, isGeneric);
  final implements = _crossImplements(config, unit, index, units);

  final buf = StringBuffer();
  buf.writeln("import 'package:erp_scale_sim/core/src/common_app_export.dart';");
  buf.writeln("import '../../bloc/feature_bloc_base.dart';");
  buf.writeln("import '../../state/feature_state.dart';");
  buf.writeln("import '../../events/feature_event.dart';");
  buf.writeln("import '../../contracts/${unit}_contract.dart';");
  buf.writeln("import '../../../../domain/entities/${unit}_ent.dart';");
  buf.writeln("import '../../../../domain/use_cases/${unit}_use_case.dart';");
  if (unit != 'reactive_form_session') {
    final relPath = isCoreMixin(unit) ? '' : '../core/';
    buf.writeln("import '${relPath}reactive_form_session_mixin.dart';");
  }
  if (config.cross > 0 && index != 0 && index % config.cross == 0) {
    final sibling = units[(index + 1) % units.length];
    buf.writeln("import '../../contracts/${sibling}_contract.dart';");
  }
  if (config.chain > 0 && index != 0 && index % config.chain == 0) {
    final prev = units[index - 1];
    if (prev != 'reactive_form_session') {
      final rel = isCoreMixin(unit) == isCoreMixin(prev) ? '' : (isCoreMixin(unit) ? '../operations/' : '../core/');
      buf.writeln("import '$rel${prev}_mixin.dart';");
    }
  }
  buf.writeln("import '../../events/${eventDir(unit).split('/').last}/${unit}_event.dart';");
  buf.writeln();

  // Private state
  buf.writeln('class $stateCls {');
  buf.writeln('  int loadCount = 0;');
  buf.writeln('  int submitCount = 0;');
  buf.writeln('  final Map<String, dynamic> cache = {};');
  buf.writeln('  final Set<String> pendingKeys = {};');
  buf.writeln('  Completer<void>? inFlight;');
  buf.writeln('  ScrMode mode = ScrMode.view;');
  buf.writeln('}');
  buf.writeln();

  // Mixin
  buf.writeln('mixin $cls$typeParam on $onClause$implements {');
  buf.writeln('  final $stateCls _${camel}State = $stateCls();');
  buf.writeln();
  buf.writeln('  @override');
  buf.writeln('  SubState<${toPascal(unit)}Ent>? get ${camel}OnLoadState =>');
  buf.writeln('      state.stateProps.${camel}OnLoadState;');
  buf.writeln();
  buf.writeln('  void register${toPascal(unit)}MixinHandlers() {');
  buf.writeln('    on<$eventCls>((event, emit) async {');
  buf.writeln('      switch (event) {');
  for (var m = 0; m < config.methods; m++) {
    final opName = m == 0
        ? 'Load'
        : m == 1
            ? 'Submit'
            : m == 2
                ? 'Refresh'
                : m == 3
                    ? 'Reset'
                    : 'Op$m';
    buf.writeln('        case ${toPascal(unit)}${opName}Event():');
    buf.writeln('          await _handle${toPascal(unit)}$opName(event, emit);');
  }
  buf.writeln('      }');
  buf.writeln('    });');
  buf.writeln('  }');
  buf.writeln();

  // Public API methods
  for (var m = 0; m < config.methods; m++) {
    if (m == 0) {
      buf.writeln('  @override');
      buf.writeln('  Future<void> load${toPascal(unit)}Screen({String? docSrl, bool force = false}) {');
      buf.writeln('    return dispatchWithCompleter(${toPascal(unit)}LoadEvent(docSrl: docSrl, force: force));');
      buf.writeln('  }');
    } else if (m == 1) {
      buf.writeln('  @override');
      buf.writeln('  Future<void> submit${toPascal(unit)}({int payload = 0, Map<String, dynamic>? currentPk}) {');
      buf.writeln('    return dispatchWithCompleter(${toPascal(unit)}SubmitEvent(payload: payload, currentPk: currentPk));');
      buf.writeln('  }');
    } else if (m == 2) {
      buf.writeln('  @override');
      buf.writeln('  Future<bool> refresh${toPascal(unit)}({int pgNo = 1, int pgSz = 20}) async {');
      buf.writeln('    final c = Completer<bool>();');
      buf.writeln('    add(${toPascal(unit)}RefreshEvent(pgNo: pgNo, pgSz: pgSz, completer: c));');
      buf.writeln('    return c.future;');
      buf.writeln('  }');
    } else if (m == 3) {
      buf.writeln('  @override');
      buf.writeln('  void reset${toPascal(unit)}() {');
      buf.writeln('    add(const ${toPascal(unit)}ResetEvent());');
      buf.writeln('  }');
    } else {
      buf.writeln('  @override');
      buf.writeln('  Future<void> execute${toPascal(unit)}Op$m({Map<String, dynamic>? params}) {');
      buf.writeln('    return dispatchWithCompleter(${toPascal(unit)}Op${m}Event(params: params));');
      buf.writeln('  }');
    }
    buf.writeln();
  }

  // Private handlers
  final castSuffix = isGeneric ? ' as $stateType' : '';
  for (var m = 0; m < config.methods; m++) {
    final opName = m == 0
        ? 'Load'
        : m == 1
            ? 'Submit'
            : m == 2
                ? 'Refresh'
                : m == 3
                    ? 'Reset'
                    : 'Op$m';
    buf.writeln('  Future<void> _handle${toPascal(unit)}$opName(');
    buf.writeln('    ${toPascal(unit)}${opName}Event event,');
    buf.writeln('    Emitter<$stateType> emit,');
    buf.writeln('  ) async {');
    buf.writeln('    _${camel}State.loadCount++;');
    buf.writeln('    emit(state.copyWith(');
    buf.writeln('      loaderStatus: LoaderStatus.loading,');
    buf.writeln('      stateProps: state.stateProps.copyWith(');
    buf.writeln('        ${camel}OnLoadState: const SubState.loading(),');
    buf.writeln('      ),');
    buf.writeln('    )$castSuffix);');
    buf.writeln('    final result = await featureUseCases.${camel}UseCase.call(');
    buf.writeln('      ${toPascal(unit)}Params(screenId: screenId, payload: event.hashCode),');
    buf.writeln('    );');
    buf.writeln('    safeFold(result, (data) {');
    buf.writeln('      _${camel}State.cache[\'$unit\'] = data.toJson();');
    buf.writeln('      emit(state.copyWith(');
    buf.writeln('        loaderStatus: LoaderStatus.loaded,');
    buf.writeln('        stateProps: state.stateProps.copyWith(');
    buf.writeln('          ${camel}OnLoadState: SubState.loaded(data),');
    buf.writeln('        ),');
    buf.writeln('      )$castSuffix);');
    buf.writeln('    }, (failure) {');
    buf.writeln('      emit(state.copyWith(');
    buf.writeln('        loaderStatus: LoaderStatus.error,');
    buf.writeln('        stateProps: state.stateProps.copyWith(');
    buf.writeln('          ${camel}OnLoadState: SubState.error(failure.message),');
    buf.writeln('        ),');
    buf.writeln('      )$castSuffix);');
    buf.writeln('    });');
    if (m == 2) {
      buf.writeln('    event.completer?.complete(true);');
    }
    buf.writeln('  }');
    buf.writeln();
  }

  // Padding to reach ~270 lines average
  for (var p = 0; p < 8; p++) {
    buf.writeln('  // $unit helper $p: validates mode branch');
    buf.writeln('  bool _${camel}Validate$p(ScrMode mode) => _${camel}State.mode == mode;');
  }
  buf.writeln();
  buf.writeln('  bool check${toPascal(unit)}Mode(ScrMode mode) =>');
  final checkLines = List.generate(8, (p) => '      _${camel}Validate$p(mode)').join(' ||\n');
  buf.writeln('$checkLines;');

  buf.writeln('}');
  return buf.toString();
}

String _mixinOnClause(
  GenConfig config,
  String unit,
  int index,
  List<String> units,
  bool isGeneric,
) {
  final base = isGeneric
      ? (unit == 'reactive_form_session'
          ? 'FeatureBlocBase<T>, Bloc<FeatureEvent, T>'
          : 'FeatureBlocBase<T>, Bloc<FeatureEvent, T>, ReactiveFormSessionMixin<T>')
      : (unit == 'reactive_form_session'
          ? 'FeatureBlocBase<FeatureState>, Bloc<FeatureEvent, FeatureState>'
          : 'FeatureBlocBase<FeatureState>, Bloc<FeatureEvent, FeatureState>, ReactiveFormSessionMixin');
  if (config.chain <= 0 || index == 0) return base;
  if (index % config.chain != 0) return base;
  final prevIdx = index - 1;
  if (prevIdx < 0) return base;
  final prev = units[prevIdx];
  if (prev == 'reactive_form_session') return base;
  if (!isGeneric || nonGenericMixins.contains(prev)) {
    return '$base, ${mixinClassName(prev)}';
  }
  return '$base, ${mixinClassName(prev)}<T>';
}

String _crossImplements(
  GenConfig config,
  String unit,
  int index,
  List<String> units,
) {
  final contract = mixinContractName(unit);
  if (config.cross <= 0 || index % config.cross != 0 || index == 0) {
    return ' implements $contract';
  }
  final sibling = units[(index + 1) % units.length];
  return ' implements $contract, ${mixinContractName(sibling)}';
}

String generateEventFile(GenConfig config, String unit) {
  final buf = StringBuffer();
  buf.writeln("import 'dart:async';");
  buf.writeln("import '../feature_event.dart';");
  buf.writeln();
  buf.writeln('sealed class ${eventClassName(unit)} extends FeatureEvent {');
  buf.writeln('  const ${eventClassName(unit)}();');
  buf.writeln('  @override');
  buf.writeln('  List<Object?> get props => [];');
  buf.writeln('}');
  buf.writeln();

  for (var m = 0; m < config.methods; m++) {
    final opName = m == 0 ? 'Load' : m == 1 ? 'Submit' : m == 2 ? 'Refresh' : m == 3 ? 'Reset' : 'Op$m';
    final cls = '${toPascal(unit)}${opName}Event';
    if (m == 0) {
      buf.writeln('final class $cls extends ${eventClassName(unit)} {');
      buf.writeln('  const $cls({this.docSrl, this.force = false});');
      buf.writeln('  final String? docSrl;');
      buf.writeln('  final bool force;');
      buf.writeln('  @override');
      buf.writeln('  List<Object?> get props => [docSrl, force];');
      buf.writeln('}');
    } else if (m == 1) {
      buf.writeln('final class $cls extends ${eventClassName(unit)} {');
      buf.writeln('  const $cls({this.payload = 0, this.currentPk});');
      buf.writeln('  final int payload;');
      buf.writeln('  final Map<String, dynamic>? currentPk;');
      buf.writeln('  @override');
      buf.writeln('  List<Object?> get props => [payload, currentPk];');
      buf.writeln('}');
    } else if (m == 2) {
      buf.writeln('final class $cls extends ${eventClassName(unit)} {');
      buf.writeln('  const $cls({this.pgNo = 1, this.pgSz = 20, this.completer});');
      buf.writeln('  final int pgNo;');
      buf.writeln('  final int pgSz;');
      buf.writeln('  final Completer<bool>? completer;');
      buf.writeln('  @override');
      buf.writeln('  List<Object?> get props => [pgNo, pgSz];');
      buf.writeln('}');
    } else if (m == 3) {
      buf.writeln('final class $cls extends ${eventClassName(unit)} {');
      buf.writeln('  const $cls();');
      buf.writeln('}');
    } else {
      buf.writeln('final class $cls extends ${eventClassName(unit)} {');
      buf.writeln('  const $cls({this.params});');
      buf.writeln('  final Map<String, dynamic>? params;');
      buf.writeln('  @override');
      buf.writeln('  List<Object?> get props => [params];');
      buf.writeln('}');
    }
    buf.writeln();
  }
  return buf.toString();
}

String generateUseCaseFile(String unit) {
  return '''
import 'package:erp_scale_sim/core/types/either_types.dart';
import '../entities/${unit}_ent.dart';

class ${toPascal(unit)}Params {
  const ${toPascal(unit)}Params({required this.screenId, this.payload = 0});
  final String screenId;
  final int payload;
}

class ${useCaseClassName(unit)} {
  Future<Either<Failure, ${toPascal(unit)}Ent>> call(${toPascal(unit)}Params params) async {
    await Future<void>.delayed(Duration.zero);
    return Right(${toPascal(unit)}Ent(
      screenId: params.screenId,
      payload: params.payload,
      unit: '$unit',
    ));
  }
}
''';
}

String generateEntityFile(String unit) {
  return '''
class ${toPascal(unit)}Ent {
  const ${toPascal(unit)}Ent({
    required this.screenId,
    required this.payload,
    required this.unit,
  });

  final String screenId;
  final int payload;
  final String unit;

  Map<String, dynamic> toJson() => {
        'screenId': screenId,
        'payload': payload,
        'unit': unit,
      };
}
''';
}
