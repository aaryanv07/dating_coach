# Phase 6A.3: Physical Native Extraction Qualification

## Status

`BLOCKED` on 2026-07-15. No qualifying physical Android or iOS run could
start on this workstation, so Phase 6A.3 is not complete and Phase 6B has not
started.

This is a truthful prerequisite block, not a native benchmark failure. Phase
6A.3 made no production runtime, backend, API, database, extraction, benchmark,
fixture, or quality-gate change. It only re-executed the existing qualification
workflow and records its content-free result.

## Required preconditions and observed environment

The existing common runner requires Flutter, each platform's complete native
toolchain, and a supported physical device visible to both the native tooling
and Flutter. A simulator, emulator, browser, desktop target, or host reference
run cannot satisfy the physical-device gate.

| Platform | Required | Observed | Result |
| --- | --- | --- | --- |
| Android | Android SDK and ADB, accepted licenses, supported physical device, install permission | Android Studio 2026.1.2, command-line tools 20.0, ADB/platform tools 37.0.0, API and Build Tools 36, NDK 28.2.13676358, CMake 3.22.1, and licenses are ready; no physical Android device is detected | `BLOCKED`: `physical_android_device_unavailable` |
| iOS | Complete Xcode selected with `xcode-select`, CocoaPods, signing/install configuration, supported physical iPhone | CocoaPods 1.17.0 is ready; complete Xcode is unavailable and no physical iOS device is detected | `BLOCKED`: `xcode_unavailable`, `physical_ios_device_unavailable` |

The Dart SDK was 3.12.2. No physical devices were used. Android native runs:
zero. iOS native runs: zero. Consequently, there are no first- or second-run
native reports and no cross-run or cross-platform native comparison.

## Qualification evidence

`dart run tool/run_phase6a2_native.dart` produced the expected exit code 2 and
content-free evidence under `apps/mobile/build/phase6a-readiness`. The reports
contain stable prerequisite reason codes and no device IDs, user-assigned device
names, screenshots, OCR text, transcripts, paths, or hashes.

After the initial blocked report, the Android toolchain and CocoaPods were
installed. The readiness runner was executed again. It still returned the
expected exit code 2, but Android is now blocked only by the missing physical
device, while iOS is blocked by complete Xcode and the missing physical iPhone.
The workstation has about 17 GiB free after safe package-cache cleanup, which is
not enough headroom to install and initialize full Xcode safely.

An Android debug-APK preflight reached production dependency compilation and
failed in `irondash_engine_context` 0.5.5 because its CargoKit Gradle script
calls the removed `Project.exec()` API under Gradle 9.1. Flutter also attempted
to replace the explicit Android minimum SDK 23 with its current default; that
incidental production compatibility change was reverted. The dependency/build
compatibility defect remains documented and unfixed pending separate
authorization, as required by this phase's scope.

The provider-neutral seven-fixture reference suite was rerun to verify all
platform-independent behavior without claiming ML Kit evidence. It completed
all seven cases with no failure or cancellation and passed every non-native
gate:

- character, word, message extraction, event classification, minimum-fixture,
  speaker, timestamp, duplicate-removal, ordering, warning, and review-recall
  accuracy: 100%;
- manual-review rate: 3.57%;
- P95 host-reference latency: 623 ms;
- maximum host-reference peak RSS delta: 36,028,416 bytes;
- cleanup success: 100%; and
- cancellation probe: passed.

The reference report remains correctly `BLOCKED` only because
`native_device_run` is false. A self-comparison produced `NO_REGRESSION` with no
blocking regressions. These host measurements validate the harness and
provider-neutral extraction behavior; they do not establish native ML Kit
accuracy, latency, memory, or classifier quality.

## Native checks that could not be performed

Because neither physical platform passed readiness, Phase 6A.3 has no evidence
for:

- two consecutive physical-device runs on Android or iOS;
- native OCR, reaction recognition, or reaction-target accuracy;
- native latency, memory, stability, failure cleanup, or cancellation behavior;
- comparison between repeated native reports; or
- physical-device screen-reader, text-scaling, touch-target, contrast, and
  reduced-motion smoke checks.

Host tests continue to cover deterministic cleanup, cancellation, privacy,
semantics, 200 percent text scaling, touch targets, and reduced-motion behavior.
They are regression evidence only and are not represented as the missing
physical-device qualification.

## Privacy and release-artifact review

No real conversation or user data was used. The benchmark uses only original
synthetic fixtures, creates screenshots in temporary directories, and deletes
temporary sources through the existing cleanup paths. Readiness and comparison
exports remain content-free. No screenshot, transcript, prompt, device
identifier, source path, or source hash was uploaded or added to an export.

A clean release bundle was produced after `flutter clean`. Both the release
artifact path scan and the synthetic-corpus content scan passed. A prior local
`build/flutter_assets` directory contained stale test-build benchmark assets;
the directory was removed by the clean build and was not present in the clean
release artifact. This does not change the application source or asset manifest.

## Verification performed

The Phase 6A.3 verification pass produced these results:

- `flutter pub get`, Dart formatting, `flutter analyze`: passed;
- `flutter test`: all 82 tests passed;
- provider-neutral reference benchmark: passed all platform-independent gates;
- self-comparison: `NO_REGRESSION`;
- clean Flutter release bundle and both release-artifact scans: passed;
- Ruff formatting/lint, MyPy across 42 source files, and `pip check`: passed;
- Pytest with warnings treated as errors: all 43 tests passed;
- isolated PostgreSQL upgrade to head, downgrade to `20260714_0003`, re-upgrade,
  and Alembic drift check: passed;
- generated OpenAPI and Pydantic JSON, fixture/schema JSON, Docker Compose
  configuration, CI YAML, privacy/prohibited-feature scans, and
  `git diff --check`: passed; and
- native readiness: expected exit 2 with only the platform prerequisite reason
  codes listed above;
- Android Studio, Android command-line tools, API/Build Tools 36, ADB, the exact
  Flutter NDK, CMake, Android licenses, and CocoaPods: installed and detected;
  and
- Android debug APK preflight: blocked by the existing
  `irondash_engine_context`/Gradle 9.1 incompatibility described above.

## Failed gates and next decision

The required physical-platform availability, `native_device_run`, two-run
consistency, native reaction, native accuracy, native performance, native
cleanup/cancellation, and physical accessibility gates remain unsatisfied.

Android physical execution also requires either a separately authorized,
backward-compatible correction for the CargoKit/Gradle incompatibility or a
compatible authoritative build-tool resolution. It must not be hidden by an
unreviewed dependency or minimum-SDK change.

Remain `BLOCKED`. Install/configure full Xcode, resolve the Android build
compatibility defect under explicit authorization, connect supported physical
devices, rerun two consecutive unchanged production pipeline qualifications per
required device class, validate and compare every content-free report, perform
the physical accessibility smoke checks, and review every gate. Do not begin
Phase 6B until both platform suites pass.
