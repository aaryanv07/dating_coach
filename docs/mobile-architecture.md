# Mobile Architecture

## Scope

The Phase 6A.2 Flutter application remains mobile-only and uses mock persistence
repositories. It adds real on-device screenshot OCR on Android/iOS while keeping
paste parsing, the Review Studio, data-quality readiness, normalization, session
persistence, and reopen behavior.
The original Phase 6A.2 path had no network client or real authentication. Phase
17 now adds authenticated conversation transport and OIDC session handling while
preserving the reviewed-event and screenshot-disposal boundaries. Billing
purchase UI and receipt handling remain absent.

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

The mock API clients remain replaceable contracts and use synthetic preview
data. `HttpConversationApiClient` is selected only for an authenticated API
configuration and retrieves the current access token per request. The visible
product name is compiled from `CONVOCOACH_APP_NAME`. No provider key, OpenAI
credential, real user identifier, or private fixture exists in the mobile
bundle.

Phase 13 validates compiled release configuration before `runApp`. Release mode
requires production environment, an HTTPS API base URL, disabled mock and Coach
preview flags, and an empty compiled access token. Android release builds may
use a complete operator-supplied signing property set but do not fall back to
the debug key. These gates add no production transport or authentication
provider.

Phase 14 adds provider-neutral mobile authentication domain contracts. Session
projections expose only lifecycle, method, and an optional server-opaque account
reference; tokens and credential bytes are deliberately absent. Phase 17
implements Authorization Code with PKCE through the system browser, a registered
custom callback, refresh-on-demand, and platform secure storage. The ID token is
not retained. Debug preview sign-in remains available only when both mock mode
and `CONVOCOACH_AUTHENTICATION_MODE=mock` are active. Release configuration
requires `oidc` and rejects a compiled access token.

Phase 15 adds a Settings plan preview with compile-time explanatory catalog copy.
It cannot activate, restore, renew, cancel, or enforce a subscription and states
that no payment information is collected. The displayed INR amounts are not
trusted purchase prices; a later live flow must use localized Apple or Google
storefront data and server-owned entitlements.

Phase 16 extends only the existing default-off Conversation Coach HTTP feature.
Its strict transport accepts the historical mock preview plus exact
`conversation-coach.v1` and Phase 17 `conversation-coach.v2` Terra responses.
Before a Terra request, the screen
shows a separate external-processing disclosure and records the user's consent
through the existing consent API. Live sections render summary, evidence-linked
observations, uncertainty, alternative interpretations, next steps, user-editable
reply drafts, safety notices, and limitations. The client cannot select the
provider, cannot access an OpenAI key, and does not persist provider output.

Phase 17 adds the server allowance snapshot to the live result and renders
explicit exhausted, rate-limited, and budget-guard states. The client creates
one canonical UUID idempotency key per pending analysis attempt, reuses it after
transport failures, and clears it only after success. It cannot set a plan,
allowance, model, price, or provider.

JPG, PNG, and WebP sources are capped at 10 images, 10 MB each, and 50 MB total.
The multi-image picker and cross-platform drop region feed an in-memory temporary
store and immediately start preparation. The presentation layer exposes one
Upload → Review → Analyze path while the application layer owns extraction,
speaker suggestions, ordering, normalization, save orchestration, and the direct
route to Conversation Coach. Optional source-order and removal controls appear
only as recovery details and are disabled while preparation is active. Sources
are cleared on abandon or successful save; processing-only cancellation retains
them for retry. `OcrEngine` owns the pipeline contract;
`TextRecognitionProvider` isolates the Google ML Kit bridge from
provider-neutral preprocessing and extraction logic.

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

Phase 19 wraps the routed application in a lifecycle privacy shield that hides
private UI outside the resumed state and respects the shared semantic theme.
Android release manifests disable backup, device transfer, and cleartext
traffic while debug retains local development HTTP. iOS packages a privacy
manifest and applies complete default data protection through configuration-
specific entitlements. These platform controls are statically tested and do not
change the user-confirmed import or AI-consent boundaries.
