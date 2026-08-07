# Phase 6A.2: Native Device Readiness

## Outcome

Phase 6A.2 makes native extraction qualification repeatable and auditable without
claiming evidence from a host, simulator, or missing toolchain. It adds no
customer feature, analytics, AI/GPT integration, scoring, coaching, payment,
subscription, cloud sync, migration, or API change. The production OCR, event,
review, normalization, and persistence boundaries remain unchanged.

The qualification harness is ready, but Phase 6A.3 remains `BLOCKED`. Android
SDK/ADB, Xcode 26.6, the iOS 26.5 runtime, and CocoaPods 1.17.0 are installed.
Android now builds on AGP 8.13.2 and Gradle 8.13 with application minSdk 24, but
still needs a supported physical device and native quality-gate closure. Xcode
has an Apple account and Personal Team configured, but iOS still needs a
supported physical iPhone to verify signing and installation. This is deferred
qualification evidence, not a release qualification.

## Qualification architecture

```mermaid
flowchart LR
    A["Common readiness entry point"] --> B["Tool and device detector"]
    B --> C{"Physical platform ready?"}
    C -- "No" --> D["BLOCKED evidence with reason codes"]
    C -- "Android" --> E["Android integration target"]
    C -- "iOS" --> F["iOS integration target"]
    E --> G["Session recorder and v2 report"]
    F --> G
    G --> H["Strict schema validation"]
    H --> I["Content-free JSON and Markdown"]
    I --> J["Previous/current regression comparison"]
```

The readiness detector probes Flutter, Android SDK/ADB, Xcode, CocoaPods, and
`flutter devices --machine`. A platform can pass readiness only with Flutter,
its required toolchain, and a supported physical device. Emulators and
simulators are visible as non-qualifying capability facts. Device command IDs
and user-assigned names are retained only in memory long enough to target
`flutter drive`; they are never serialized into evidence.

The runners are:

- `tool/run_phase6a2_android.dart` for Android;
- `tool/run_phase6a2_ios.dart` for iOS; and
- `tool/run_phase6a2_native.dart` for one or both platforms.

They invoke the existing platform-specific integration targets and common test
driver. A blocked prerequisite returns process exit code 2 and writes a
content-free reason report instead of attempting the benchmark.

## Benchmark session and result contract

Every v2 benchmark report records:

- hardware model, operating-system version, Flutter version, ML Kit adapter
  version, extraction version, and benchmark version;
- UTC start and completion times plus elapsed milliseconds;
- measured process peak RSS and peak RSS delta where available;
- completed, failed, or cancelled outcome;
- success, failure count, cancelled-case count, and cancellation-probe result;
- aggregate and per-fixture metrics; and
- explicit `PASS` or `BLOCKED` quality-gate status.

The versioned JSON Schema is
`apps/mobile/benchmark/phase6a/schema/benchmark-result-v2.schema.json`. The Dart
writer also applies an exact-field validator before writing reports. Failed
cases contain stable exception categories only. Reports cannot contain OCR text,
expected transcripts, screenshots, source paths, source hashes, device IDs, or
user-assigned device names.

## Quality gates and comparison

Phase 6A.2 adds typed-event classification accuracy to the existing extraction
gates. Required gates include zero failed and zero cancelled fixture cases,
successful cancellation cleanup, complete temporary-file cleanup, and a true
physical-device run. A host reference result is therefore expected to remain
`BLOCKED` only on `native_device_run` after every platform-independent gate
passes.

Compare a new report with a previous report from `apps/mobile`:

```bash
dart run tool/compare_phase6a_benchmarks.dart \
  build/phase6a-benchmark/previous/report.json \
  build/phase6a-benchmark/current/report.json
```

The comparison flags accuracy drops over 0.5 percentage points, manual-review
increases over 2 points, new failed/cancelled cases, cleanup drops, PASS-to-
BLOCKED changes, latency increases over both 15 percent and 100 ms, and memory
increases over both 20 percent and 10 MiB. Accuracy, failures, cancellation,
cleanup, and gate-state regressions are blocking; performance deltas are
reported for investigation. Comparison exports are aggregate and content-free.

## Expanded original synthetic coverage

The corpus now contains seven original fixtures. The two Phase 6A.2 additions
cover a light, low-contrast English/Hinglish/Roman-Hindi event timeline with
deleted, image, voice-note, encryption, and unread items, plus a dark,
emoji-heavy, reaction-heavy mixed-language layout. Together with the existing
fixtures, the suite covers light/dark themes, English, Hinglish, Roman Hindi,
emoji-only messages, reactions, overlap, crops, missing timeline sections,
out-of-order screenshots, low contrast, compact screens, and large screens.

Reaction-heavy visual overlays that are not expected to produce OCR text remain
explicit in ground truth. A separately recognized compact reaction exercises
typed reaction classification and target attachment. This distinction prevents
decorative overlay density from silently becoming expected transcript content.

## Commands

From `apps/mobile`:

```bash
dart run tool/generate_phase6a_fixture_catalog.dart
flutter test benchmark/phase6a_reference_benchmark_test.dart --reporter expanded
dart run tool/run_phase6a2_native.dart
dart run tool/run_phase6a2_android.dart --device-id=<PHYSICAL_DEVICE_ID>
dart run tool/run_phase6a2_ios.dart --device-id=<PHYSICAL_DEVICE_ID>
```

The common command writes readiness evidence under
`build/phase6a-readiness`. Successful platform benchmarks write v2 reports under
`build/phase6a-benchmark/android` or `build/phase6a-benchmark/ios`. These are
ignored build artifacts; only the synthetic JSON definitions and schema are
committed.

## Current evidence and limitations

- The seven-fixture provider-neutral reference run passes every
  platform-independent gate. It does not invoke ML Kit and cannot satisfy the
  native-device gate.
- The latest local capability report detects Flutter 3.44.6, the Android SDK,
  Xcode 26.6, and CocoaPods 1.17.0, but no qualifying mobile device. Its only
  readiness reason codes are `physical_android_device_unavailable` and
  `physical_ios_device_unavailable`.
- Two unchanged Android 16/API 36 ARM64 emulator reports completed all seven
  ML Kit fixtures and compared as `NO_REGRESSION`. They provide nonqualifying
  development measurements only: the physical-device gate remains false and
  several native extraction-quality gates are below target.
- Physical ML Kit OCR accuracy, native latency, native memory behavior, and
  classifier quality remain unverified until the documented physical suites
  run.
- RSS is process-level sampling, not a substitute for Android Studio or Xcode
  profiling.
- Original synthetic fixtures qualify defined geometry and text cases; they do
  not prove behavior for every third-party app version, font, compression path,
  language script, or accessibility configuration.
- Phase 6B has not started. It remains blocked until the required repeated
  physical Android and iOS evidence passes and is reviewed.

## Verification on this workstation

The completed Phase 6A.2 verification pass and the 2026-07-21 readiness rerun
produced these results:

- Dart formatting check and `flutter analyze`: passed with no findings;
- `flutter test`: all 82 tests passed;
- provider-neutral seven-fixture reference benchmark: all
  platform-independent gates passed, with `native_device_run` correctly
  `BLOCKED`;
- Flutter release bundle: built successfully;
- Ruff format/lint, MyPy, and `pip check`: passed;
- Pytest: all 43 tests passed with warnings treated as errors;
- isolated PostgreSQL upgrade, downgrade to `20260714_0003`, re-upgrade, and
  Alembic drift check: passed;
- Docker Compose configuration, CI YAML, fixture/schema JSON, and
  `git diff --check`: passed;
- self-comparison of the v2 reference report: `NO_REGRESSION`; and
- latest native readiness rerun: expected exit 2, with only
  `physical_android_device_unavailable` and `physical_ios_device_unavailable`.

## Phase 6A.3 execution outcome

The unchanged readiness workflow was executed again for Phase 6A.3 on
2026-07-15. The initial run found no native toolchain. Android Studio, the
required Android SDK/ADB packages and licenses, and CocoaPods were then
installed. The current capability result blocks Android only on the missing
physical Android device. A 2026-07-21 follow-up installed and selected Xcode
26.6 with the iOS 26.5 runtime; iOS is now also blocked only on its missing
physical device. A 2026-07-22 follow-up replaced the incompatible AGP 9.0.1 and
Gradle 9.1 pairing with AGP 8.13.2 and Gradle 8.13, aligned the two affected
legacy library subprojects to compile SDK 36, and raised application minSdk to
24 as required by `image_picker_android`. The debug APK now builds. Two Android
emulator ML Kit reports completed and compared without regression, but their
quality status remains `BLOCKED`; no physical benchmark was attempted and Phase
6B did not start. CocoaPods generated the standard iOS workspace integration
and lockfile needed to compile the existing plugins.

The full content-free evidence, platform-independent regression results,
unperformed native checks, and next prerequisites are recorded in
`phase-6a3-physical-native-qualification.md`.
