# Mobile Architecture

## Scope

The Phase 2 Flutter application is a mobile-only, mock-data experience. It has no
backend client, persistence, real authentication, OCR, AI, payment, or subscription
logic.

## Structure

```text
apps/mobile/lib
|-- app/                 application and GoRouter configuration
|-- core/
|   |-- config/          configurable product identity
|   |-- haptics/         interface, system implementation, test no-op
|   |-- motion/          duration resolution and reduced-motion scope
|   |-- theme/           typed semantic tokens and Material 3 themes
|   `-- widgets/         reusable buttons, cards, inputs, overlays, states
`-- features/
    |-- splash/
    |-- onboarding/
    |-- authentication/  in-memory mock session only
    |-- home/
    |-- conversations/   empty foundation state
    |-- progress/        empty foundation state
    |-- settings/
    `-- shell/           indexed bottom-navigation shell
```

Riverpod owns explicit local settings and mock-session state. GoRouter owns the
onboarding route sequence and a `StatefulShellRoute.indexedStack` so branch state
can be preserved. The central Create destination opens a bottom sheet and does
not navigate into later-phase functionality.

The visible product name is compiled from `CONVOCOACH_APP_NAME`. No provider key,
token, user identifier, or private content exists in the mobile bundle.
