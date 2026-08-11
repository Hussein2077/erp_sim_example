# erp_scale_sim

A runnable, self-contained reproduction for [flutter/flutter#190436](https://github.com/flutter/flutter/issues/190436):

**Flutter Web (DDC) compile time and startup time degrade severely when a Bloc base class applies a large number of generic mixins and is then subclassed once per screen.**

The generator in `tool/generate.dart` builds a synthetic multi-package workspace that matches the *shape* and the *scale* of the real product this was found in - an ERP front end of ~324k lines of Dart spread over 32 first-party packages - and it can emit the same workspace three times with only the behaviour-attachment strategy changed. That last part is what makes it usable as a bug report: the **composition** variant is a control group carrying more code than the **mixin** variant, so any difference in compile or startup time cannot be explained by code volume.

## Contents
* The problem
* The real application
* What the simulation reproduces
* Quick start
* Measuring
* Results

## The problem
The real app's screen controllers sit at the bottom of this chain:
```
ChartOfAccountsCubit                one of 718 screens
  -> StpBloc<T>                      abstract, in the module package
    -> FeatureBloc<T>                in the core package: applies 32 mixins,
                                     31 of them generic on <T FeatureState extends>
         -> FeatureBlocBase<T>       extends Bloc<FeatureEvent, T>
              -> Bloc<FeatureEvent, T>
```

`FeatureBloc` is declared like this (real code, `lib/features/common_feature/presentation/controllers/bloc/feature_bloc.dart`):
```dart
class FeatureBloc<T FeatureState extends> extends FeatureBlocBase<T>
    with
        ReactiveFormSessionMixin<T>,
        FeatureBodyMappingMixin,
        FocusMixin<T>,
        TotalsMixin<T>,
        GridManagerMixin<T>,
        // ... 27 more ...
        FeatureActionBarIntercept<T>
    implements IFeatureBloc<T> {
```

Four things happen once this is scaled to a real screen count:
* **DDC compile time is ~4x** an equivalent non-mixin design. Substituting the 32 generic mixins for 32 injected plain-object capabilities - same method bodies, same event families, same widget trees, more total lines - makes `flutter run`'s compile just over four times faster (62.4s vs 257.9s of app code at 800 screens). `flutter build web --release` (dart2js) is within 10%, so this is specific to the DDC path that `flutter run` uses.
* **Page load to the first line of `main()` is 1.5x slower** (31.2s vs 46.8s), because the browser has more and larger DDC modules to fetch and evaluate - even though the mixin build ships 68k fewer lines of Dart.
* **Constructing controllers is 5.5x slower** at runtime. Every instantiation walks the whole linearised mixin chain and re-registers its handler families.
* **Disposing them is 10x slower.**

The decisive data point is the third variant. **mixin-shared** is identical to **mixin** except that every screen shares one concrete state type instead of declaring its own, so the generic chain is instantiated once rather than 800 times. It is *not* faster than mixin - it measures marginally slower. The cost is dominated by applying 31 generic mixins to a Bloc at all, not by the number of distinct type arguments it is applied at. That is the part we believe is actionable.

This is not a "your app is big" report: the control group is bigger.

## The real application being simulated

`onyx_ix_erp` is a Flutter Web ERP front end. It is a core package plus 16 business-module packages consumed as git dependencies, plus one validation package nested inside almost every module.

### Package graph

```
onyx_ix_erp
├── onyx_ix (path: ../)                 app shell, 4 dart files
│   ├── file_manager (path)             core package: framework, common_feature, DI contracts
│   ├── onyx_ix_grid (git)
│   │   └── custom_data_grid
│   ├── searchable_dropdown (git)
│   ├── onyxix_api_debugger (git)
│   ├── onyx_ix_ai_chatbot (git)
│   ├── onyx_ix_calc_engine (git, pinned SHA)
│   └── calc_engine_decimal (git, same repo, path: calc_engine_decimal)
└── onyx_ix_debug_assets (path)
    16 module packages (git, ref: develop)
    ├── account_administration            └── */packages/*_validation (path)
    ├── assets_system_management
    ├── customer_relationship_management
    ├── customers_and_sales_management
    ├── fleet_management_system
    ├── general_setup
    ├── help_screens
    ├── human_capital_management
    ├── inventory_systems_management
    ├── management_information_system
    ├── manufacturing_facilities_management
    ├── pos_management
    ├── project_management_system
    ├── real_estate_management
    ├── system_administration
    └── vendor_and_purchase_management
```

Every module git-depends back on `onyx_ix`, and 14 of the 16 carry a nested `packages/<module>_validation` path package. The app's resolved package graph is 327 packages in total.

The counts in the next section cover the 32 packages that hold the application code: the core package, the 16 modules, their 14 validation packages and the app shell. The 8 remaining first-party packages (`onyx_ix_grid`, `searchable_dropdown`, `onyxix_api_debugger`, `onyx_ix_ai_chatbot`, `onyx_ix_calc_engine`, `calc_engine_decimal`, `file_manager`, `onyx_ix_debug_assets`) are shared infrastructure and are excluded.

### Real file and line counts
Measured on the checked-out `develop` refs:

| layer | packages | .dart files | lines of Dart | barrel files |
|---|---|---|---|---|
| core `onyx_ix` (`lib/`) | 1 | 1,085 | 98,560 | 122 |
| 16 business modules | 16 | 4,946 | 213,431 | 709 |
| nested `*_validation` packages | 14 | 384 | 11,827 | 5 |
| app shell `onyx_ix_erp/lib` | 1 | 4 | 229 | 0 |
| **total** | **32** | **6,419** | **324,047** | **836** |

Core package breakdown:
| files |
|---|
| `lib/core/` (25 subdirectories) |
| `lib/features/` (7 features) |

The 7 core features are `ai_chat`, `app_layout`, `auth`, `common_feature`, `dashboard`, `landing_page`, `splash`. `common_feature` is the one that matters: it holds the `FeatureBloc` chain every screen in every module inherits from.

Module breakdown, by file kind, across all 16:
| kind | count |
|---|---|
| screen definitions (`*_def.dart`) | 718 |
| screen controllers (`*_cubit.dart`) | 693 |
| screen views (`*_view.dart`) | 624 |
| screen-registration lists (`screens.dart`, `<group>_screens.dart`, `core_screens.dart`) | 49 |
| validator definitions (`*_vld_def.dart`) | 368 (+243 in the validation packages) |
| link-key definitions | 10 |
| domain contracts (`*_cont.dart`) | 118 |
| repositories | 114 |
| remote data sources | 111 |
| use cases | 79 |
| module-local mixins | 79 |
| entities and models | 183 |
| widgets | 229 |
| own state classes | 20 |

Note the last row: only 20 of the 693 controllers declare their own state class. The rest reuse the shared `FeatureState`, which is why the simulation offers both `mixin` (per-screen state type) and `mixin-shared` (one shared state type) - the real app is much closer to `mixin-shared`, and it is *still* 4.4x slower to compile under DDC than the composition control.

### The controllers layer that triggers it
`lib/features/common_feature/presentation/controllers/`:

| count | lines |
|---|---|
| `mixins/core/*_mixin.dart` | 22 |
| `mixins/operations/*_mixin.dart` | 10 |
| **mixins total** | **32** |

All 32 are in `FeatureBloc`'s `with` clause; 31 are generic on `<T FeatureState extends>`. The largest are `grid_manager_mixin.dart` (1,090 lines), `vlds_mixin.dart` (954), `totals_mixin.dart` (740), `load_scr_mixin.dart` (558), `update_mixin.dart` (527) and `setup_mixin.dart` (461); the average is ~270 lines.

The four files next to them are small by comparison - `feature_bloc.dart` is 73 lines, `feature_bloc_base.dart` 44, `feature_contract_bloc.dart` 24 - so the generated simulation matches the real mixin sizes rather than the real declaration site.

Registration is per-mixin and cumulative: `FeatureBloc.registerFeatureEventHandlers` calls `registerFocusMixinHandlers()`, `registerUiMixinHandlers()`, `registerTotalsMixinHandlers()` and 29 more, and each module controller overrides it to call `super` plus its own. A screen built at runtime therefore registers its full handler set across three packages.

### Dependency injection
Screens are never imported by the shell. `lib/core/contracts/` defines `ScreenDefinition` / `ScreenRegistry` / `ScreenCaller`, `ModuleRegistry` / `ModuleCaller`, `FieldVldDefinition` / `ValidatorsRegistry` / `ValidatorsCaller`, and `LinkKeyDefinition` / `LinkKeyRegistry` / `LinkKeyCaller`; `lib/core/injection/` holds `get_it`, `CoreInjector` and `InjectHelper`. Each module exposes `<Abbrev>InitGetIt.knowModule()`, and a screen's dependencies are registered only when `ScreenCaller` first resolves it. The simulation reproduces this whole mechanism, because lazy registration is what keeps the *startup* numbers honest.

### Dependencies
`onyx_ix` declares 70 dependency entries (67 packages + 3 Flutter SDK entries: flutter, flutter_web_plugins, flutter_localizations), of which 6 are git and 1 is a local path:

| area | packages |
|---|---|
| state / DI | flutter_bloc, hydrated_bloc, bloc_concurrency, get_it, equatable, dartz |
| network | dio, dio_cache_interceptor, pretty_dio_logger, http, connectivity_plus |
| forms | reactive_forms, queen_validators |
| first-party (git) | onyx_ix_grid, searchable_dropdown, onyxix_api_debugger, onyx_ix_ai_chatbot, onyx_ix_calc_engine, calc_engine_decimal |
| charts / visualisation | syncfusion_flutter_charts, countries_world_map, carousel_slider, marquee_list |
| documents / files | pdf, printing, excel, csv, file_picker, open_file, file_manager (path), path_provider |
| media | just_audio, just_audio_web, record, video_compress, flutter_image_compress, cached_network_image, flutter_svg, lottie |
| rich text | flutter_quill, vsc_quill_delta_to_html, html |
| UI / UX | google_fonts, font_awesome_flutter, flutter_spinkit, skeletonizer, shimmer, flutter_animate, add_to_cart_animation, flutter_hooks, device_preview, flutter_fullscreen, edge_alerts |
| routing | go_router |
| security / storage | flutter_secure_storage, crypto, local_auth, local_session_timeout, flutter_dotenv |
| platform / misc | url_launcher, device_info_plus, simple_barcode_scanner, omni_datetime_picker, easy_debounce, intl, web, leak_tracker |

`onyx_ix_erp` declares 19 entries: flutter, two path deps (`onyx_ix`, `onyx_ix_debug_assets`) and the 16 module git deps. Modules add only what they need on top of `onyx_ix` (e.g. `general_setup` adds `excel` and `file_picker`).

### Assets
|  |  |
|---|---|
| core `assets/lang/` | 2 localisation files |
| app images | 43 |
| app audio | 3 |
| font files | 13 |
| font families | 2 ('Cairo', 'ReadexPro', 'NotoNaskhArabic'), 3 weights each |
| other app assets | `.env`, `config.json`, web splash GIF |
| module-declared assets | 1 (`general_setup`, an XLSX import template) |
| **total** | **64 files** |

Assets are listed for completeness. They are not part of the reproduction: the simulation ships no assets beyond Material icons, and the effect reproduces without them.

## What the simulation reproduces

### Fidelity
| dimension | real app | erp_scale_sim at the documented flags |
|---|---|---|
| packages | 32 first-party | 17 (core + 15 modules + app) |
| dart files | 6,419 | ~5,300 |
| lines of Dart | 324,047 | ~318,000 ('composition') / ~250,000 ('mixin') |
| screens | 718 | 800 |
| mixins in the core chain | 22 (31 generic) | 29 (+3 per module controller) |
| mixin size | avg ~270 lines | avg ~270 lines |
| screen definitions | 718 | 800 |
| barrel files | 836 | 1,717 |
| screens with own state type | 20 of 692 | mixin-shared = 0, mixin = all 800 |
| DI | get_it + registry/caller contracts, lazy per screen | same mechanism, same class names |
| layers per screen | ds -> repo -> use case -> cubit -> view | same |
| dependency style | path + git | path only (offline-reproducible) |
| assets | 64 files, 3 font families | none |
| business logic | real | synthetic; use cases resolve immediately, no HTTP |

The `mixin` variant carries fewer lines than the real app because sharing one state type (as the real app mostly does) removes per-screen state files; the `composition` control lands closest to the real line count.

### Layout produced
The workspace root *is* the core package, the way `onyx_ix` is:

```
...
pubspec.yaml                  core package: erp_scale_sim
lib/erp_scale_sim.dart        re-exports core/src/common_app_export.dart
lib/core/
  network/                    ApiService, ConfigReader, BaseUrlConfig,
                              TokenService, CachingService, connectivity
  contracts/screens/          ScreenDefinition, ScreenRegistry, ScreenCaller
  contracts/modules/          ModuleRegistry, ModuleCaller
  contracts/vld/              FieldVldDefinition, ValidatorsRegistry/Caller
  contracts/link_keys/        LinkKeyDefinition, LinkKeyRegistry/Caller
  injection/                  getIt, CoreInjector, InjectHelper
  src/common_app_export.dart  the import every generated file uses
  enums/, constants/, helpers/, types/ LoaderStatus, ScrMode, Either, Failure
  shared_cubits/              SubState<T>, SafeBloc, safeFold
  grid/, reactive_forms/      grid state manager, form session
lib/features/common_feature/
  data/datasources/, data/repos/ FeatureRemoteDataSource, FeatureRepo
  domain/contracts/           FeatureContract
  domain/use_cases/<unit>_use_case.dart one per mixin, plus FeatureUseCases
  domain/vlds/, domain/link_keys/ FieldVldDefinition / LinkKeyDefinition impls
  injection/common_feature_injection.dart CommonFeatureInjection.register()
  presentation/controllers/
    bloc/feature_bloc_base.dart extends Bloc<FeatureEvent, T>, with SafeBloc
    bloc/feature_bloc.dart      applies every mixin, implements IFeatureBloc<T>
    bloc/feature_contract_bloc.dart IFeatureBloc<T>, aggregates all mixin contracts
    events/core/operations/<unit>_event.dart sealed event family per mixin
    mixins/core/<unit>_mixin.dart 19 generic mixins
    mixins/operations/<unit>_mixin.dart 10 generic mixins
    state/                    FeatureState + props classes
    presentation/template/   CommonFeatureDef + CommonFeatureView
    presentation/view/widgets/ shared field, grid and scaffold widgets

packages/module_01 .. module_15/
  lib/module_NN.dart          barrel
  lib/core/mNN_injection/     MNNInitGetIt.knowModule(), screen injections,
                              validators, link keys
  lib/screens.dart            registers every screen def with ScreenRegistry
  lib/src/common/presentation/controllers/
    bloc/module_NN_bloc.dart  abstract module controller
    bloc/module_NN_contract_bloc.dart IModuleNNBloc<T>
    events/, mixins/          the module's own events and mixins
  lib/src/features/screen_XXXX/
    presentation/controllers/bloc/state/ screen bloc and state
    presentation/def/screen_XXXX_def.dart ScreenDefinition: bloc factory + view builder
    presentation/view/screen_XXXX_view.dart screen view

app/
  lib/core/injection/injector.dart GetItInjector.init() (generated)
  lib/gen/registry.dart      constants + screen id list (generated)
  lib/main.dart               instrumented startup harness (hand-written)
...
```

Only `app/lib/main.dart`, `app/lib/startup_report.dart`, `app/web/` and the two scripts in `tool/` are hand-written. Everything under `lib/`, `packages/`, `app/lib/core/` and `app/lib/gen/` is generated and git-ignored.

### What one mixin file contains
Each generated mixin mirrors the real `delete_mixin.dart`: a contract, a private per-feature state class, and a generic mixin constrained on the bloc base plus the session mixin.

```dart
abstract class IDeleteMixin {
  SubState<DeleteEnt>? get deleteOnLoadState;
  Future<void> loadDeleteScreen({String? docSrl, bool force = false});
  Future<void> submitDelete({int payload = 0, Map<String, dynamic>? currentPk});
  Future<bool> refreshDelete({int pgNo = 1, int pgSz = 20});
  void resetDelete();
}

class _DeleteMixinState { /* counters, cache, pending keys, in-flight completer */ }

mixin DeleteMixin<T FeatureState extends> on FeatureBlocBase<T>, ReactiveFormSessionMixin<T>
    implements IDeleteMixin {
  final _DeleteMixinState _state = _DeleteMixinState();

  void registerDeleteMixinHandlers() { /* on<DeleteEvent>, switch over the sealed family */ }
  // public API via dispatchWithCompleter, then private handlers that emit
  // loading, await the use case, safeFold the Either and emit loaded/error
  // through state.copyWith(props: state.props.copyWith(...)) as T
}
```

So every mixin carries the same machinery as the real ones: sealed events with completers, `emit(... as T)` through nested `copyWith`, `safeFold` over `Either<Failure, T>`, private scratch state and a screen-mode branch. Generated mixins land at ~230-320 lines, against the real average of ~270.

### The chain each screen sits at the bottom of
```
Screen0123Bloc
  -> Module03Bloc<T>         abstract, in the module package, with Module03Mixin0..2<T>,
                             implements IModule03Bloc<T>
       -> FeatureBloc<T>     in the core package, with ReactiveFormSessionMixin<T>,
                             FeatureBodyMappingMixin and 29 unit mixins,
                             implements IFeatureBloc<T>
            -> FeatureBlocBase<T> extends Bloc<FeatureEvent, T>, with SafeBloc
                 -> Bloc<FeatureEvent, T>
```

## The three variants
All three generate the same package count, the same feature folders, the same barrels, the same DI, the same widget trees and a comparable volume of handler logic. Only how behaviour is attached differs.

| `--arch` | Screen controller | Generic mixin chain |
|---|---|---|
| `composition` | extends `Module02Bloc` extends `FeatureController`, behaviour from `List<FeatureCapability>` | never instantiated |
| `mixin-shared` | extends `Module03Bloc<CommonFeatureState>` | instantiated once |
| `mixin` | extends `Module02Bloc<Screen0123State>` | instantiated once per screen |

In `composition` each unit is a `FeatureCapability` object with its own contract and private state class, holding the same method bodies against a `FeatureStore` window onto the controller - no generics, no mixins, same volume of logic, and in fact more total lines.

## Requirements
Flutter stable with web support. Verified on Flutter 3.44.8 / Dart 3.12.2, Windows Server 2022, 32 logical cores.

## Quick start
```bash
dart run tool/generate.dart --arch=mixin --modules=15 --screens=800 --mixins=29
cd app
flutter pub get
flutter run -d chrome
```

Then repeat with `--arch=composition` and compare. Nothing is downloaded beyond the normal pub dependencies; every generated package is a path dependency.

## Matching your own codebase
Every dimension is a flag, and the generator prints the resulting package, file and line counts so a target can be dialled in:
```bash
dart run tool/generate.dart \
  --arch=mixin \
  --modules=15 \         # module packages
  --screens=800 \        # screens spread across the modules
  --mixins=29 \          # mixins in the core chain (19 core + 10 operations)
  --module-mixins=3 \    # extra mixins added by each module controller
  --widgets=24 \         # form fields per screen view, the main lever on UI volume
  --methods=5 \          # async handler methods per mixin, the lever on mixin length
  --chain=4 \            # every Nth mixin constrains on the previous one
  --cross=3              # every Nth mixin implements a sibling's contract
```

The mixin names are the real ones (`load_scr`, `vlds`, `grid_manager`, `totals`, `delete`, `approved`, `posting`, `suspend`, ...), so the generated tree reads like the project it stands in for.

## Measuring compile time
```bash
# both compile paths, all three architectures, at 800 screens
dart run tool/bench.dart --screens=800 --mode=all

# a scaling curve
dart run tool/bench.dart --screens=200,400,800 --mode=ddc

# rebuild the report from previous runs
dart run tool/bench.dart --report
```

`--mode=release` times `flutter build web --release` (dart2js). `--mode=ddc` times `flutter run -d web-server` up to the moment the app is served, which is the compile path `flutter run` uses.

Each run is preceded by `flutter clean`, and `flutter pub get` is timed separately because resolving 17 path packages is itself part of the cost of this layout. Every matrix starts with a floor measurement - one module, one screen, two mixins - so the report can subtract fixed toolchain cost and report the time attributable to the generated architecture.

Outputs land in `bench/results/`: `results.csv`, `summary.md` and full `--verbose` logs per run under `logs/`.

## Measuring runtime startup
Compile time and startup time are separate symptoms. Run the app and read the on-screen table, which is also printed to the console:
```bash
cd app
flutter run -d chrome
```

`app/lib/main.dart` times the real boot sequence with `performance.now()`:

| phase | what it covers |
|---|---|
| page load -> `main()` entry | everything the browser does before the first line of Dart app code: fetching and evaluating every DDC module in the workspace |
| `CoreInjector.initFirst()` | network layer |
| `GetItInjector.init()` | core contracts + 15 module factories |
| `ModuleCaller.callAllModules()` | every module's registration runs; fills `ScreenRegistry` with 801 screen defs |
| resolve first screen | first `ScreenCaller.callCubit()`, which triggers the lazy `CommonFeatureInjection` |
| resolve remaining screens | 799 more screens, each registering its full handler set |
| drive one op per unit | one operation per mixin on the warmed screens |
| close controllers | teardown |
| first frame rendered | wall clock from page load |

Knobs are URL query parameters, so startup can be re-measured against the same compiled output:
```
http://localhost:PORT/?instantiate=200&warm=10
http://localhost:PORT/?skipRuntime=1      # startup with no controllers built
http://localhost:PORT/?page=17            # open generated screen 17
```

## Results
800 screens / 15 modules / 29 core mixins (+2 per module), Flutter 3.44.8, Windows Server 2022, 32 logical cores. "app code" subtracts a measured toolchain floor of 28.8s (release) / 38.4s (DDC), taken from a one-module one-screen build in the same matrix.

### Compile
|  | composition | mixin | mixin-shared |
|---|---|---|---|
| dart files | 5,293 | 5,272 | 5,272 |
| lines of Dart | 317,952 | 250,207 | 238,207 |
| dart2js, app code | 68.9s | 74.0s (1.07x) | 75.7s (1.10x) |
| DDC, app code | 62.4s | 257.9s (4.13x) | 272.1s (4.36x) |
| DDC, per 1k LOC | 0.20s | 1.03s | 1.14s |
| main.dart.js | 8.33 MB | 9.82 MB | 9.58 MB |

The `mixin` variants carry 21-25% fewer lines than the `composition` control, yet DDC takes over 4x as long on them. dart2js is within 10%. Per thousand lines of Dart, DDC is 5x more expensive on the mixin code.

`mixin-shared` - one shared state type, so the generic chain is instantiated "once" instead of 800 times - is not faster than `mixin`. It is marginally slower. Whatever DDC is doing scales with applying the mixins, not with the number of type arguments they are applied at.

### Debug runtime startup
| phase | composition | mixin | ratio |
|---|---|---|---|
| page load -> `main()` entry | 31,215.7 ms | 46,845.6 ms | 1.50x |
| `CoreInjector.initFirst()` | 6.7 ms | 11.1 ms | 1.66x |
| `GetItInjector.init()` | 9.1 ms | 12.1 ms | 1.33x |
| `ModuleCaller.callAllModules()` (801 defs) | 37.9 ms | 60.9 ms | 1.61x |
| resolve first screen | 52.5 ms | 154.8 ms | 2.95x |
| resolve remaining 799 screens | 1,281.5 ms | 7,031.5 ms | 5.49x |
| drive one op per unit | 226.4 ms | 428.2 ms | 1.89x |
| close controllers | 26.2 ms | 261.6 ms | 9.98x |
| first frame rendered | 33,716.2 ms | 55,732.1 ms | 1.65x |

DDC compile for these same two runs: 113.3s composition, 320.2s mixin.

Three things stand out:
 * **Module evaluation.** 15.6s more time before the first line of `main()` runs, on a build that contains 68k fewer lines of Dart. The emitted DDC modules are bigger and more numerous for the mixin design.
 * **Construction.** Resolving 799 screens is 5.5x slower. Each construction walks the linearised chain of 32 mixins and re-registers every handler family through three packages.
 * **Disposal.** 10x slower, which suggests the per-instance cost is structural to the flattened chain rather than to the handler registration alone.

The registration phases that do *not* touch the mixin chain (`initFirst`, `GetItInjector.init`, `callAllModules`) are within 1.3-1.7x, which is roughly the general debug-mode overhead of the larger module graph. The gap only becomes dramatic where controllers are actually built.

Full tables, raw CSV rows and per-run `--verbose` logs:
`bench/results/summary.md` (bench/results/summary.md),
`bench/results/results.csv`, `bench/results/logs/`.

## Scope and limitations
 * **Synthetic**: no HTTP, no real business logic, no assets beyond Material icons. Use cases resolve immediately instead of hitting a network. The point is the *shape* of the code the compiler sees, not what it does.
 * Timings vary by several seconds between runs; use `--repeat=3` for numbers worth arguing over.
 * Runtime numbers are debug-mode (DDC) only. A release build's startup is a different measurement and is not the subject of this report.
 * `lib/`, `packages/`, `app/lib/core/` and `app/lib/gen/` are git-ignored. Run the generator after cloning.
