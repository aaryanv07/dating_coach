# Mobile Architecture

## Scope

The Phase 6A.2 Flutter application remains mobile-only and uses mock persistence
repositories. It adds real on-device screenshot OCR on Android/iOS while keeping
paste parsing, the Review Studio, data-quality readiness, normalization, session
persistence, and reopen behavior.
It still has no network client, durable device persistence, real authentication,
AI analysis, payment, or subscription logic.

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
    |-- communication_profile/
    |   |-- domain/      UI-free entities and repository contract
    |   |-- data/        DTO, API-client contract, mock client, repository
    |   |-- application/ Riverpod async controller and providers
    |   `-- presentation/
    |-- conversations/   same domain/data/application/presentation layers
    |-- conversation_import/
    |   |-- domain/      provider-neutral OCR structures and extraction strategies
    |   |-- data/        preprocessing, ML Kit adapter, picker, temporary store
    |   |-- application/ idempotent extraction, editor history, save orchestration
    |   `-- presentation/ import and Review Studio surfaces
    |-- progress/        empty foundation state
    |-- settings/
    `-- shell/           indexed bottom-navigation shell
```

Riverpod owns explicit local settings, mock-session state, profile state, and
conversation-list state. GoRouter owns the
onboarding route sequence and a `StatefulShellRoute.indexedStack` so branch state
can be preserved. The central Create destination opens the Phase 4 import
chooser. Import routes sit outside the bottom-navigation shell so review stays
focused while the shell retains its branch state.

The mock API clients are replaceable contracts and use synthetic preview data.
No bearer-token storage or HTTP implementation is included in Phase 4. The
visible product name is compiled from `CONVOCOACH_APP_NAME`. No provider key,
token, real user identifier, or private content exists in the mobile bundle.

JPG, PNG, and WebP sources are capped at 10 images, 10 MB each, and 50 MB total.
The multi-image picker and cross-platform drop region feed an in-memory temporary
store. Sources can be reordered or removed before extraction and are cleared on
abandon or successful save. Processing-only cancellation retains them for retry.
`OcrEngine` owns the pipeline contract; `TextRecognitionProvider` isolates the
Google ML Kit bridge from provider-neutral preprocessing and extraction logic.

Phase 6A qualification code lives under `benchmark/`, `integration_test/`, and
`test_driver/`; no benchmark route or customer-facing screen is added. Ground
truth JSON produces temporary original Canvas fixtures. The same `OcrEngine`
pipeline runs with deterministic reference lines on the host and ML Kit on
physical devices. Reports export only content-free metrics and fixture IDs.

Phase 6A.2 keeps the customer runtime path unchanged and adds
qualification-only modules beside it: a strict v2 result/schema boundary,
session recorder, tool/device capability detector, Android/iOS/common runners,
and previous/current comparison. The detector never serializes device command
IDs or user-assigned names. A simulator can assist development but cannot set
the native quality gate to PASS.

`Conversation-Event-Spec.md` defines the typed-event domain and Review Studio
behavior. Phase 6A.1 implements the closed event and relationship enums, typed
normalized records and DTOs, the full event sequence in Riverpod state, and an
explicit legacy message projection. A replaceable deterministic classifier
preserves date separators and distinguishes standalone emoji from compact
reactions. Review Studio renders event-specific icons and labels and supports
type, target, speaker, timestamp, text, delete/restore, and unknown corrections.
The 50-snapshot undo/redo boundary remains in place. Native extraction quality
and performance still require the Phase 6A physical-device suite.
