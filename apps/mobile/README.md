# ConvoCoach Mobile

Flutter Android/iOS application for the ConvoCoach consumer experience.

The current build includes premium onboarding, privacy and age gates,
mock authentication, GoRouter navigation, light/dark/system themes, reusable UI
states, motion and haptic foundations, a basic communication-profile flow, and a
mock conversation list. Domain models, DTOs, API-client contracts, repositories,
and Riverpod providers remain backed by synthetic in-memory data. Phase 5 adds a
provider-neutral extraction pipeline with Google ML Kit text recognition on
supported Android and iOS devices, bounded image preprocessing, geometric message
grouping, speaker and timestamp strategies, overlap detection, and content-free
extraction metadata. Unsupported platforms and deterministic tests retain the
mock OCR implementation. The Conversation Review Studio remains the required
confirmation step. Screenshot bytes stay in temporary session storage and are
not sent to the backend. Phase 6A.1 adds typed event and relationship models,
event-aware normalization and readiness, deterministic reaction classification,
and Review Studio type/relationship/timestamp corrections. It keeps the legacy
message projection for compatibility and does not perform AI analysis.

Phase 6A adds a development-only synthetic fixture and benchmark harness under
`benchmark/` and `integration_test/`. It exports content-free JSON and Markdown
results and adds no customer-facing screen. See
`../../docs/phase-6a-native-extraction-qualification.md` for reference and
physical-device commands. Phase 6A.2 adds strict versioned result validation,
session metadata, device/tool readiness detection, Android/iOS/common runners,
regression comparison, and two additional original typed-event fixtures. See
`../../docs/phase-6a2-native-device-readiness.md` for the repeatable workflow.

## Run

```bash
flutter pub get
flutter run
```

## Verify

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter build bundle --release
flutter test benchmark/phase6a_reference_benchmark_test.dart
dart run tool/run_phase6a2_native.dart
```

Android and iOS builds require their respective SDK toolchains. The package name
is `convo_coach`; the visible product name is configurable through
`--dart-define=CONVOCOACH_APP_NAME=...`.
