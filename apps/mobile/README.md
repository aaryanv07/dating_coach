# ConvoCoach Mobile

Flutter Android/iOS application for the ConvoCoach consumer experience.

The current Phase 2 build includes premium onboarding, privacy and age gates,
mock authentication, GoRouter navigation, light/dark/system themes, reusable UI
states, motion and haptic foundations, and accessibility tests. It uses mock,
in-memory state and does not access private conversations or backend APIs.

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
```

Android and iOS builds require their respective SDK toolchains. The package name
is `convo_coach`; the visible product name is configurable through
`--dart-define=CONVOCOACH_APP_NAME=...`.
