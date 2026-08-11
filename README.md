# erp_scale_sim

A runnable, self-contained reproduction for [flutter/flutter#190436](https://github.com/flutter/flutter/issues/190436):

**Flutter Web (DDC) compile time and startup time degrade severely when a Bloc base class applies a large number of generic mixins and is then subclassed once per screen.**

The generator in `tool/generate.dart` builds a synthetic multi-package workspace that matches the *shape* and the *scale* of the real product this was found in — an ERP front end of ~324k lines of Dart spread over 32 first-party packages — and it can emit the same workspace three times with only the behaviour-attachment strategy changed. That last part is what makes it usable as a bug report: the **composition** variant is a control group carrying more code than the **mixin** variant, so any difference in compile or startup time cannot be explained by code volume.

## Quick start

```bash
dart run tool/generate.dart --arch=mixin --modules=15 --screens=800 --mixins=29
cd app
flutter pub get
flutter run -d chrome
```

Then repeat with `--arch=composition` and compare.

## Three variants

| `--arch` | Screen controller | Generic mixin chain |
|---|---|---|
| `composition` | extends `ModuleNNBloc` extends `FeatureController`, behaviour from `List<FeatureCapability>` | never instantiated |
| `mixin-shared` | extends `ModuleNNBloc<CommonFeatureState>` | instantiated once |
| `mixin` | extends `ModuleNNBloc<ScreenNNNNState>` | instantiated once per screen |

## Generator flags

```bash
dart run tool/generate.dart \
  --arch=mixin \
  --modules=15 \
  --screens=800 \
  --mixins=29 \
  --module-mixins=3 \
  --widgets=24 \
  --methods=5 \
  --chain=4 \
  --cross=3
```

## Measuring compile time

```bash
dart run tool/bench.dart --screens=800 --mode=all
dart run tool/bench.dart --screens=200,400,800 --mode=ddc
dart run tool/bench.dart --report
```

## Measuring runtime startup

Run the app and read the on-screen table (also printed to console):

```bash
cd app
flutter run -d chrome
```

URL query parameters:

- `?instantiate=200&warm=10` — limit controller construction
- `?skipRuntime=1` — startup with no controllers built
- `?page=17` — open generated screen 17

## Layout

```
erp_scale_sim/          # core package (workspace root)
  tool/generate.dart    # generator
  tool/bench.dart       # benchmark harness
  lib/                  # generated core package
  packages/module_NN/   # generated module packages
  app/                  # runnable Flutter Web shell
    lib/main.dart       # instrumented startup harness
    lib/startup_report.dart
    web/
```

Everything under `lib/`, `packages/`, `app/lib/core/` and `app/lib/gen/` is **generated** and git-ignored. Run the generator after cloning.

## Requirements

Flutter stable with web support. Verified on Flutter 3.44.8 / Dart 3.12.2.
