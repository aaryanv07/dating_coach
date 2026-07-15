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
not sent to the backend. The app does not perform AI analysis.

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
```

Android and iOS builds require their respective SDK toolchains. The package name
is `convo_coach`; the visible product name is configurable through
`--dart-define=CONVOCOACH_APP_NAME=...`.
