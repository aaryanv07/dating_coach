# Phase 6A.3: Physical Native Extraction Qualification

## Status

`BLOCKED`, most recently rechecked on 2026-08-12. Android now has two
consecutive unchanged physical-device runs that pass every required extraction
gate. The iPhone result still misses required extraction gates, and the physical
accessibility smoke checks remain unperformed. Phase 6A.3 therefore remains
incomplete; the passing Android result is not represented as full
cross-platform qualification.

This remains a truthful qualification block. The qualification workflow made
no backend, API, database, extraction, benchmark, fixture, or quality-gate
change. The follow-up changed only source-controlled native build compatibility:
Android now uses AGP 8.13.2 and Gradle 8.13, both affected legacy library
subprojects compile against SDK 36, and the application minimum SDK is 24 as
required by the selected `image_picker_android` release. The iOS follow-up
generated the standard CocoaPods workspace integration and lockfile needed to
compile the existing plugins. Debug, Profile, and Release now include their
matching Pods configurations. Android 6.0/API 23 is no longer supported; no
other customer behavior changed.

## Required preconditions and observed environment

The existing common runner requires Flutter, each platform's complete native
toolchain, and a supported physical device visible to both the native tooling
and Flutter. A simulator, emulator, browser, desktop target, or host reference
run cannot satisfy the physical-device gate.

| Platform | Required | Observed | Result |
| --- | --- | --- | --- |
| Android | Android SDK and ADB, accepted licenses, supported physical device, install permission | Android Studio 2026.1.2, command-line tools 20.0, ADB/platform tools 37.0.1, API and Build Tools 36, NDK 28.2.13676358, CMake 3.22.1, and licenses are ready. A Xiaomi 21091116I on Android 13 completed two consecutive unchanged seven-fixture physical suites through the production ML Kit adapter. | `PASS`: every required gate passed twice; p95 latency was 2,103 ms and 2,136 ms. |
| iOS | Complete Xcode selected with `xcode-select`, CocoaPods, signing/install configuration, supported physical iPhone | Xcode 26.6, CocoaPods 1.17.0, a Personal Team, and an iPhone 13 Pro Max on iOS 26.5.2 are ready. Signing, standalone Profile installation, launch, and the seven-fixture native suite completed | `BLOCKED`: event classification 94.76% is below 95%, and minimum fixture message extraction 80% is below 90% |

Qualifying Android physical runs: two consecutive unchanged runs. Completed iOS
physical runs: one, still blocked by required quality gates. There is no passing
cross-platform native comparison.

## Qualification evidence

`dart run tool/run_phase6a2_native.dart` produced the expected exit code 2 and
content-free evidence under `apps/mobile/build/phase6a-readiness`. The reports
contain stable prerequisite reason codes and no device IDs, user-assigned device
names, screenshots, OCR text, transcripts, paths, or hashes.

After the initial blocked report, the Android toolchain and CocoaPods were
installed. Xcode 26.6 and the iOS 26.5 runtime were subsequently installed, and
`xcode-select` now points to the Xcode bundle on the external development SSD.
Xcode Derived Data is stored directly on the external development SSD, the
default Compilation Cache resolves under that Derived Data root, and the default
Archives path is symlink-backed to the SSD. Dart and Gradle caches are also
SSD-backed to preserve internal-disk headroom. The readiness rerun returned the
expected exit code 2 with only
`physical_android_device_unavailable` and
`physical_ios_device_unavailable`.

The authorized Android compatibility correction replaced the incompatible AGP
9.0.1 and Gradle 9.1 pairing with AGP 8.13.2 and Gradle 8.13. It applies a
targeted compile-SDK 36 override to `irondash_engine_context` and
`super_native_extensions`, whose released Android projects hard-code compile
SDK 31 while their current AndroidX dependencies require API 34 or later. The
application minimum SDK is explicitly 24 because the selected
`image_picker_android` manifest requires API 24. No generated package-cache
file was patched. `flutter build apk --debug` now passes. The release shrinker
also ignores only the absent optional Chinese, Devanagari, Japanese, and Korean
recognizer namespaces referenced by the generic Flutter adapter; ConvoCoach
instantiates only `TextRecognitionScript.latin`. The release AAB now builds.

Two unchanged Android 16/API 36 ARM64 emulator runs then completed the seven
synthetic fixtures through the production ML Kit adapter. Both completed 7/7
fixtures with zero failures or cancellations, 100% temporary-file cleanup, a
passing cancellation probe, and passing latency and memory gates. The
content-free reports compared as `NO_REGRESSION` with no blocking regressions.
They also consistently failed several extraction-quality gates: message
extraction 92.86% against 95%, event classification 79.17% against 95%, minimum
fixture message extraction 75% against 90%, speaker assignment 92.86% against
95%, timestamp accuracy 92.86% against 98%, warning accuracy 71.43% against
90%, and review recall 85.71% against 95%. These are development findings, not
physical-device evidence, and the required thresholds have not been weakened.

A temporary content-free structure diagnostic narrowed those misses without
logging recognized text, image data, paths, hashes, timestamps, or device
identity. ML Kit supplied no candidate region for the two emoji-only message
cases or the compact reaction expected as recognized text, so the downstream
event classifier had no evidence to classify. All received text messages,
structural events, ordering, and duplicate boundaries matched their expected
types. The low-contrast fixture also retained provider confidence above the
review threshold. Adding a downstream guess would fabricate content; a future
correction must introduce a separately reviewed, on-device visual-region
evidence boundary with explicit uncertainty and focused original synthetic
tests.

On 2026-08-10, a Xiaomi 21091116I running Android 13/API 33 was authorized
over ADB. The debug manifest required a narrowly scoped merge override so its
USB-local development HTTP route could coexist with the release
`usesCleartextTraffic=false` policy; a regression test protects the release and
debug declarations. The first physical run completed all seven original
synthetic fixtures with zero failures or cancellations, 100% cleanup, a passing
cancellation probe, 98.43% character accuracy, 95.95% word accuracy, 100%
message extraction, 97.62% event classification, and a 54.5 MB maximum RSS
delta. It is still `BLOCKED`: warning accuracy was 78.57% against 90%, review
recall was 85.71% against 95%, and p95 latency was 4,520 ms against 2,500 ms.
The report contains aggregate metrics and synthetic fixture IDs only. The
user-facing arm64 debug app was reinstalled after the benchmark and cold-launched
successfully; the benchmark result does not claim Android launch qualification
or an App Store/Play Store release.

On 2026-08-12, the Android production adapter was corrected without weakening
any quality gate. A single ML Kit recognizer is reused within an import and
closed with its owning scope. Preprocessing is bounded to one screenshot ahead
of recognition. Preprocessing also emits a compact metadata-free luminance
raster, so confidence calibration does not decode the sanitized screenshot a
second time. The engine rejects pre-cancelled work before creating temporary
resources and still awaits bounded in-flight preprocessing on failure. Focused
tests cover reuse, cleanup, cancellation, low-contrast review, the compact
raster, and the bounded pipeline.

Two consecutive unchanged physical runs then passed every required gate. Both
completed all seven synthetic fixtures with no failure or cancellation, 98.43%
character accuracy, 95.95% word accuracy, 100% message extraction, 97.62% event
classification, 100% speaker/timestamp/ordering/deduplication accuracy, 92.86%
warning accuracy, 100% review recall, 100% cleanup, and a passing cancellation
probe. Run 1 measured 2,103 ms p95 latency and a 62,902,272-byte maximum RSS
delta; run 2 measured 2,136 ms and 57,143,296 bytes. The nonrequired manual
review rate was 57.14%, with 71.43% review precision; these are disclosed and
were not treated as release-blocking gates. Reports contain only aggregate
metrics and synthetic fixture IDs. Their content-free comparison returned
`NO_REGRESSION` with no blocking regressions. After qualification, the normal
universal debug app version 0.2.0+2006 was rebuilt, installed, cold-launched in
4,267 ms, remained resumed for 15 seconds, and produced no fatal Android or
Flutter log.
This establishes the documented Android extraction qualification, not Play
Store production deployment.

On 2026-07-30, the Apple Development key partition access was repaired with
explicit owner approval. A signed Profile app installed and relaunched directly
through iOS without Flutter tooling, remained alive, and reached the local
conversation-list endpoint successfully. The physical iPhone benchmark then
completed 7/7 fixtures with no failures or cancellations, 100% cleanup, a
passing cancellation probe, 1,191 ms p95 latency, 73,138,176 bytes maximum peak
RSS delta, 97.14% message extraction accuracy, and 94.76% event classification
accuracy. The report is still `BLOCKED`: event classification is below the 95%
gate and one cropped-thread fixture produced 80% message extraction against the
90% minimum-fixture gate. The thresholds were not weakened.

A bounded native-OCR line-gap correction was added with a regression test to
keep loose, partially cropped wrapped lines together without merging the next
bubble. A follow-up physical run built and installed but wireless VM-service
discovery timed out, so the correction has not yet produced replacement
physical evidence.

A debug iOS simulator build completed and produced `Runner.app`. The current
Google ML Kit pods do not supply the arm64 simulator slices required by iOS 26
on Apple silicon, so Flutter produced an x86_64-only simulator application. The
iOS 26.5 simulator rejected it at installation with a matching-architecture
error. This is development evidence only: simulator execution cannot satisfy
the physical-device gate. Separate unsigned arm64 physical-iPhone debug and
release target builds completed successfully, but they cannot establish signing,
installation, runtime, OCR, performance, or accessibility evidence without a
connected iPhone.

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

## Native checks still required

The current evidence still does not establish:

- two consecutive unchanged passing physical-device runs on iOS;
- passing iOS minimum-fixture and event-classification gates;
- a passing cross-platform native comparison; or
- physical-device screen-reader, text-scaling, touch-target, contrast, and
  reduced-motion smoke checks on both platforms.

Host tests continue to cover deterministic cleanup, cancellation, privacy,
semantics, 200 percent text scaling, touch targets, and reduced-motion behavior.
The Android emulator adds nonqualifying production-adapter evidence. Neither is
represented as the missing physical-device qualification.

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
  Flutter NDK, CMake, Android licenses, Xcode 26.6, the iOS 26.5 runtime, and
  CocoaPods: installed and detected;
- `flutter doctor -v`: no issues found;
- iOS simulator debug compile: passed; installation on the Apple-silicon iOS
  26.5 simulator: blocked by the x86_64-only ML Kit dependency result described
  above;
- unsigned arm64 physical-iPhone debug and release target compiles: passed;
  signing, installation, and execution remain unperformed without a physical
  device;
- `pod install --deployment`: passed without a base-configuration warning after
  the Debug/Profile/Release Pods includes were aligned;
- Android debug APK build: passed with the source-controlled compatibility
  baseline described above;
- Android release AAB: passed after adding the narrowly scoped optional-ML-Kit
  shrinker rules described above; and
- two Android emulator ML Kit runs: 7/7 fixtures completed with no failure or
  cancellation, cleanup/cancellation/performance gates passed, comparison
  `NO_REGRESSION`, but the extraction-quality gates listed above remain
  `BLOCKED`; and
- temporary content-free Android structure diagnostic: passed and isolated
  omitted emoji/reaction candidates plus the low-contrast confidence mismatch;
  the diagnostic source was removed after use.

## Failed gates and next decision

Android physical extraction, performance, cleanup, cancellation, and two-run
consistency gates are satisfied. The corresponding iOS extraction and two-run
gates, cross-platform passing comparison, and physical accessibility gates
remain unsatisfied.

Remain `BLOCKED`. Investigate the failing iOS synthetic cases without logging or
exporting message content, add focused regression coverage for every correction,
and keep every existing quality threshold. Then run two consecutive unchanged
iPhone production-pipeline qualifications, validate and compare every
content-free report, perform the physical accessibility smoke checks on both
platforms, and review every gate before production release.
