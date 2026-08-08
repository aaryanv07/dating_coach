# Decision Log

## 2026-07-26: Phase 15 fixes the catalog while keeping purchases disabled

The approved commercial model is a no-card 30-day welcome allowance, a
permanent limited Free plan, and ConvoCoach Plus at INR 999 monthly or INR 8,999
annually. Weekly subscriptions and unlimited-AI claims are excluded. Safety,
privacy, export, deletion, and existing results are never paywalled.

Phase 15 adds an immutable, content-free backend catalog and allowance evaluator
plus a truthful mobile preview. Every plan remains `purchase_enabled=false`.
There is no route, persistence, migration, store dependency, receipt, payment,
entitlement, quota decrement, external AI execution, or release authorization.
Future localized store data and server verification must remain authoritative.

## 2026-07-25: Phase 14 aggregates release evidence but cannot authorize launch

Production identity now has bounded claim contracts, exact issuer/audience/JWKS
and asymmetric-algorithm policy, and a fail-closed `production_contract` mode.
No production adapter exists, so every production credential is rejected.
Mobile release mode exposes only an explicit unavailable sign-in state; tokens
and provider SDKs remain absent.

Release qualification uses strict content-free manifest, supply-chain,
artifact-provenance, and gate contracts plus a deterministic evaluator. The
checked-in example must evaluate as blocked. Neither a manual gate record nor
build success may override missing production authentication, signing,
physical-device evidence, clean revision provenance, or controlled-launch
approval.

This phase adds no route, persistence, schema, migration, deployment, store
submission, production AI, coaching, Communication DNA, or later-phase work.
Phase 6A.3 remains blocked. No commit or push is authorized by the Phase 14
prompt.

## 2026-07-25: Phase 13 fails closed before serving production traffic

Production configuration is now validated before the application is accepted.
Startup requires read-only PostgreSQL connectivity, exact Alembic revision, and
Redis connectivity checks. Liveness remains dependency-free; readiness reports
the stored lifecycle and dependency states without applying migrations.

An outer request boundary owns canonical correlation UUIDs, content-free
allowlisted JSON logs, bounded bodies, safe unexpected errors, trusted hosts,
security/privacy headers, and production-disabled OpenAPI. Mobile release mode
requires an HTTPS endpoint, disables mock and Coach preview behavior, and
rejects compiled access tokens. Android release builds no longer use debug
signing.

This operational foundation is not a deployment and does not authorize a
production AI provider, SDK, outbound AI networking, prompt execution,
coaching, generation, scoring, persistence, schema change, or migration.
Phase 6A.3 remains blocked and mandatory; Phase 14 has not started.

## 2026-07-25: Phase 12 registers architecture, not a production provider

The provider boundary now has immutable metadata, a closed registry,
deterministic compatibility selection, structural health, and a factory so a
future provider adapter can fit the internal pipeline without changing mobile
or API contracts. This is architecture preparation only.

The deterministic mock is the sole active and executable registration. Future
production metadata must remain inactive, and the registry and factory both
reject active or executable non-mock providers. Health is structural and
performs no live probe. Runtime configuration reuses only the two existing
default-off booleans and cannot contain provider credentials or endpoints. No
external SDK, network capability, provider implementation, API change,
persistence, migration, coaching, generation, summary, or score is authorized.
Phase 6A.3 remains blocked and mandatory.

## 2026-07-25: Phase 11 exposes only a default-off mock vertical slice

The first Conversation Coach transport is an authenticated, owner-bound,
consent-gated POST with an empty request body. It converts only confirmed
persisted canonical events into the existing Phase 10 pipeline and returns only
the validated Phase 9 renderer projection. Separate server execution and mock
flags plus a build-time mobile gate default off. The slice adds no external
provider, prompt execution, coaching content, persistence, migration, queue,
stream, or background job. Phase 6A.3 remains blocked and mandatory.

## 2026-07-24: Phase 10 integrates only the deterministic mock pipeline

The application now has one internal execution coordinator, but neither a
customer feature nor provider execution is enabled. Both coordinator flags
default off, and the only permitted provider identifier is the Phase 8
deterministic mock. The coordinator must execute analytics, minimized evidence,
safety, request construction, provider boundary, provider parsing, structured
placeholder construction/parsing, response validation, and renderer projection
in order.

Lifecycle identifiers use UUIDv5 from explicit request/prompt inputs; no random
or wall-clock identifier is allowed. Diagnostics contain only ordered stage and
status values. Cancellation and timeout can interrupt any stage and wrap the
provider await. A failure never falls through to a later stage. No public API,
job, persistence, transport, external model, prompt execution, advice, or UI is
authorized. Phase 6A.3 remains blocked.

## 2026-07-24: Phase 9 models AI responses without generating advice

The first layer above Phase 8 is a provider-independent structured response
contract, not a coaching feature. Phase 9 therefore uses closed capability and
unavailable-result identifiers, structural evidence links, allowlisted
localization keys, evidence-sufficiency descriptors, safety codes, and
provenance versions. It contains no prose or advice field.

A deterministic local mock may populate only infrastructure placeholders and
must mark real coaching capabilities unavailable. Strict parsing rejects
unknown shapes, unknown capability identifiers, invalid versions, and
content-bearing fields. Typed validation restricts every UUID and metric
reference to one explicit minimized Phase 8 evidence package. Renderer models
carry localization/semantic keys and counts only; no UI is authorized. AI and
prompt execution remain disabled, and Phase 6A.3 remains blocked.

## 2026-07-24: Phase 8 creates a disabled provider-neutral AI boundary

Phase 8 may establish future AI architecture but may not deliver AI behavior.
The implementation therefore packages only reviewed canonical structure and
selected deterministic Phase 6B analytics, validates explicit readiness and
quality requirements, builds an immutable request, and uses an injected provider
behind one orchestrator. The runtime feature flag defaults off, and the only
implementation is a deterministic local mock returning a structured placeholder.

Prompt templates are versioned localization-aware descriptors without prompt
text or business logic. No external service, provider SDK, model, secret,
network call, route, database migration, persistence, queue, cache, UI, score,
coaching, interpretation, recommendation, reply, first message, or summary is
authorized. Evidence never includes screenshots, OCR, message content, source
metadata, participant names, or excluded events. Provider failures are
content-safe. Any later transport must preserve the repository and orchestration
abstractions. Phase 6A.3 remains blocked and mandatory before release.

## 2026-07-23: Phase 7 is a read-only conversation-data presentation boundary

Phase 7 consumes immutable `conversation-analytics.v1` values through an
injectable Flutter repository boundary. The backend Phase 6B engine remains the
only calculation owner. The mobile mapper may select metrics, format supplied
values, summarize supplied availability states, and show supplied structural
evidence, but it may not reproduce formulas, infer missing values, or create a
score or interpretation.

No analytics API, database change, persistence, history, cache, export, AI,
scoring, coaching, reply generation, first-message generation, OCR change, or
native-qualification change is authorized. Because there is no analytics
transport in this phase, the default repository returns no result and the UI
shows an empty state. Tests use injected content-free synthetic snapshots only.
Customer copy calls the surface **conversation data** and explicitly states that
it does not measure interest, compatibility, or relationship quality. Phase
6A.3 remains `BLOCKED` and mandatory before production release.

## 2026-07-23: Phase 6B proceeds while physical qualification remains a release gate

The user-authorized Agenda Discussion sequencing decision permits build phases
to continue through the planned application scope while physical Android/iOS
qualification is deferred. Automated verification remains mandatory after every
phase. This supersedes only the earlier sequencing block: it does not change a
Phase 6A fixture, threshold, runner, result, or production release gate. Phase
6A.3 remains truthfully `BLOCKED`, emulator/host evidence remains
nonqualifying, and production release still requires the missing physical OCR,
accuracy, performance, cleanup, cancellation, and accessibility evidence.

Phase 6B therefore implements one bounded internal capability: deterministic
analytics over accepted `conversation-events.v1` timelines. The canonical
formulas live in `Analytics-Specification.md`; immutable results contain
structural UUID evidence and explicit data quality. No mobile UI, API route,
database migration, persistence, cache, dashboard, score, semantic analysis,
AI/GPT, coaching, reply generation, first-message generation, event-model
change, Review Studio change, extraction modification, or physical
qualification is included.

## 2026-07-22: Simulator preflight restores Android builds and exposes native quality gaps

Simulator development was authorized before physical-device qualification. The
Android build now uses AGP 8.13.2 and Gradle 8.13, avoiding CargoKit's removed
Gradle 9 `Project.exec()` path. A source-controlled root-project override raises
only the `irondash_engine_context` and `super_native_extensions` library
subprojects from their hard-coded compile SDK 31 to compile SDK 36. The selected
`image_picker_android` version requires API 24, so the application minimum SDK
is now 24; Android 6.0/API 23 is no longer supported. No target SDK, permission,
OCR algorithm, backend, API, database, or fixture changed.

The debug APK builds successfully. The first release-bundle attempt exposed R8
references to optional Chinese, Devanagari, Japanese, and Korean ML Kit
recognizer classes that are intentionally not bundled. The app instantiates
only `TextRecognitionScript.latin`, so a source-controlled shrinker file now
suppresses only those absent optional namespaces; the 74.5 MB release AAB then
built successfully. Two unchanged Android 16/API 36 ARM64 emulator runs
completed all seven synthetic ML Kit cases with no failure or cancellation,
full cleanup, and `NO_REGRESSION` between reports. The reports remain
`BLOCKED`: simulators cannot satisfy `native_device_run`, and message
extraction, typed-event classification, minimum-fixture extraction, speaker,
timestamp, warning, and review-recall gates were below target. The iOS simulator
build still produces an x86_64-only app because current Google ML Kit pods lack
the arm64 simulator slice required by Apple-silicon iOS 26; installation fails
with a matching-architecture error. Phase 6A.3 and Phase 6B remain blocked.
The checked-in CocoaPods integration now gives Debug, Profile, and Release their
matching Pods configuration includes; `pod install --deployment` verifies the
lockfile without configuration warnings, and the unsigned physical-iPhone
release target still builds.

A temporary content-free structure diagnostic isolated the Android quality
misses without logging recognized text, image data, paths, hashes, timestamps,
or device identity. The Latin ML Kit adapter omitted both emoji-only message
regions and the one compact reaction marked for text recognition. Every
received text message, date separator, media placeholder, deleted marker,
encryption notice, unread separator, page order, and duplicate boundary was
otherwise classified as expected. The low-contrast fixture also retained
provider confidence above the review threshold. No downstream rule now invents
missing content: remediation requires a separately reviewed on-device visual
region/evidence boundary that can surface omitted items with explicit
uncertainty and focused synthetic tests.

## 2026-07-21: Complete Xcode narrows readiness to physical devices

Xcode 26.6, the iOS 26.5 simulator runtime, and CocoaPods 1.17.0 are installed;
`xcode-select` points to the Xcode bundle on the external development SSD.
Xcode Derived Data and its default Compilation Cache are stored on the SSD; the
default Archives path is symlink-backed to the SSD. Dart and Gradle package
caches are also SSD-backed. `flutter doctor -v` reports no issues and the
unchanged native readiness detector now reports only
`physical_android_device_unavailable` and `physical_ios_device_unavailable`.

A debug iOS simulator compile succeeds. Installation on an Apple-silicon iOS
26.5 simulator is nonqualifying and fails because the current Google ML Kit pods
force an x86_64-only simulator artifact. Separate unsigned arm64 device debug
and release builds succeed. An Apple account and Personal Team are configured,
leaving physical signing, installation, and qualification for the
connected-device run. The Android debug APK still stops in
`irondash_engine_context` 0.5.5 because Gradle 9.1 removed `Project.exec()`.
Neither compatibility issue is being hidden by a minimum-SDK rewrite or an
unreviewed dependency patch. Phase 6A.3 remains blocked until supported physical
devices pass the existing suites, and Phase 6B remains closed.

## 2026-07-15: Native tool setup does not expand Phase 6A.3 scope

Android Studio 2026.1.2, the Flutter-required Android SDK/ADB components and
licenses, and CocoaPods 1.17.0 are installed. Android readiness is now blocked
only by a physical device, while iOS still needs full Xcode and a physical
iPhone. An APK preflight revealed an existing `irondash_engine_context` 0.5.5
CargoKit incompatibility with Gradle 9.1. Flutter's attempted minimum-SDK rewrite
was reverted. The production dependency/build correction requires separate
authorization and Phase 6B remains closed.

## 2026-07-15: Phase 6A.3 remains blocked at physical prerequisites

The Phase 6A.3 execution used the existing unchanged qualification runner and
stopped before native benchmark execution. Android had no SDK or physical
device; iOS had no complete Xcode, CocoaPods, or physical device. Host reference
and repository regression checks remain green, but they cannot substitute for
two consecutive physical runs, native reaction/accuracy/performance evidence,
or physical accessibility smoke checks. No runtime behavior changed and Phase
6B must not start until both platform suites pass every documented gate.

## 2026-07-15: Phase 6A.2 makes native qualification truthful and repeatable

The repository now owns Android, iOS, and common qualification runners, a
tool/device capability detector, benchmark session evidence, a strict v2 JSON
contract, explicit PASS/BLOCKED evaluation, and previous/current regression
comparison. A platform is ready only with Flutter, its complete native toolchain,
and a supported physical device. Simulator/host evidence cannot satisfy the
native gate. Device IDs and user-assigned names remain in-memory runner inputs
and are omitted from reports. This phase changes no customer runtime, backend
API, migration, analytics, AI, scoring, generation, payment, or subscription
behavior.

## 2026-07-15: Typed-event qualification uses expanded original fixtures

Two new original fixtures cover media placeholders, deleted/system events,
mixed English/Hinglish and Roman Hindi, emoji-heavy and reaction-heavy layouts,
and low contrast. The benchmark now gates typed-event classification accuracy
alongside extraction accuracy. Visual reaction overlays are explicit ground
truth and only enter classification expectations when marked as recognized OCR
text; this prevents decorative density from becoming fabricated transcript
content.

## 2026-07-15: Phase 6A.1 implements events beside legacy messages

`Conversation-Event-Spec.md` establishes the architecture baseline for typed
conversation events, relationships, confidence, Review Studio behavior,
analytics inclusion, privacy, and reversible persistence. The explicit Phase
6A.1 authorization introduces event tables, a `conversation-events.v1` endpoint,
typed extraction output, deterministic classification, and Review Studio event
corrections. Legacy messages are not backfilled or rewritten; event GET performs
an explicit read-time projection only when needed. Analytics and intelligence
remain unauthorized, and physical native qualification remains outstanding.

## 2026-07-15: Phase 5 is extraction, not analysis

The explicit implementation request defines Phase 5 as the Real Conversation
Extraction Engine even though the static roadmap in `master-build-prompt.md`
labels Phase 5 as analysis. The explicit request controls this phase. No
analysis, scoring, generation, OpenAI, or GPT behavior is introduced.

## 2026-07-15: On-device screenshot processing is the primary path

The AI architecture previously described mandatory backend object storage before
OCR while also naming on-device ML Kit as preferred. For the current mobile
path, screenshots remain temporary on-device, ML Kit runs on-device, and only
user-confirmed structured messages or Phase 6A.1 event contracts reach FastAPI.
Private object storage remains a possible future backend fallback and is not
part of Phase 5.

## 2026-07-15: ML Kit does not own chat layout interpretation

The `google_mlkit_text_recognition` bridge is isolated behind
`TextRecognitionProvider`. It supplies text structure, boxes, and confidence.
Grouping, speaker inference, timestamp resolution, screenshot ordering, and
overlap detection remain provider-neutral strategies because ML Kit is not a
complete chat-bubble detector.

## 2026-07-15: Extraction idempotency is private and session-scoped

Repeated requests are keyed with SHA-256 digests of temporary source bytes plus
pipeline versions. The coordinator stores at most three completed results in
memory. Source digests are not logged, sent to analytics, or persisted because a
long-lived screenshot fingerprint would exceed the purpose of provenance.

## 2026-07-15: Phase 6A qualifies extraction and does not add intelligence

The explicit Phase 6A request supersedes the static roadmap's dashboard label.
This phase adds synthetic fixture generation, ground-truth comparison, benchmark
reports, and native-device entry points only. It introduces no deterministic
conversation analytics, semantic AI, scoring, dashboard, or generation feature.

## 2026-07-15: Qualification fixtures are original synthetic archetypes

The suite uses descriptive WhatsApp-, Tinder-, Bumble-, Hinge-, and Instagram
DM-style coverage labels, but its visual system, content, geometry, and assets are
original. No real conversation, product screenshot, protected asset, or exact
competitor layout may enter the repository.

## 2026-07-15: Benchmark diagnostics and exports are content-free

Production extraction exposes only counts and ordered source indices needed for
measurement. JSON and Markdown reports contain fixture IDs and metrics, never
screenshots, transcripts, paths, or hashes. A host reference report cannot
authorize Phase 6B; required physical Android and iOS reports must pass every
documented gate first.

## 2026-07-26: Terra is backend-only, fixed, consented, and non-persistent

The authorized external AI implementation uses the OpenAI Responses API with
the exact `gpt-5.6-terra` model and a strict Pydantic output schema. Provider and
model selection are server-owned; credentials never enter Flutter. A request is
allowed only for an authenticated owner with both history and separate external
processing consent, and only bounded reviewed message text crosses the provider
boundary. The adapter requests `store=False`, uses a keyed pseudonymous safety
identifier, validates evidence references, and persists no coaching result.
Production activation remains blocked pending a separately authorized release
qualification and a billable synthetic smoke test.

## 2026-07-27: The opening borrows energy, not identity

The supplied visual reference informs the opening experience through hierarchy,
depth, static card tilt, and one brief entrance sequence. ConvoCoach uses an
original semantic-token composition, coaching copy, and interaction model; it
does not reproduce the reference's branding, assets, personality labels, or
visual scoring. The setup emphasizes that observations are uncertain and all
generated directions remain user-controlled drafts. System and in-app reduced
motion settings resolve the entrance duration to zero.

## 2026-07-27: Vibrancy supports a simpler upload-first path

The supplied product references establish a preference for bright pastel depth,
heavy headings, one dominant call to action, compact secondary choices, and a
small stable navigation surface. ConvoCoach now expresses those patterns through
its own violet, pink, and aqua semantic tokens, original synthetic chat artwork,
and a four-destination shell. Home starts screenshot or pasted-text review
directly instead of opening an intermediate create menu. The redesign explicitly
excludes copied brand assets, desirability or compatibility scores, attachment
labels, and assertions about another person's interest or intent.

## 2026-07-27: 2.5D motion stays bounded and optional

The first depth pass uses Flutter-native perspective, scale, translation,
opacity, and shadows instead of a 3D runtime. It is limited to a touch-responsive
Home preview, a synthetic screenshot-stack transition, a root-tab transition,
and one whole-result coaching reveal. Imported image bytes never enter
decorative motion. Every duration uses the existing 160–280 ms tokens, each
screen stays within three major animated moments, and reduced-motion preferences
produce the same final layouts without interpolation or tilt.

## 2026-07-27: Oceanic identity proceeds while the SIREN rename is deferred

The requested mermaid direction is implemented as an original oceanic semantic
palette, pearl-and-wave mark, iridescent typography, and one-time wave reveal.
It does not use a literal mermaid character, copied artwork, continuous particle
motion, or user screenshot bytes. A public rename to `SIREN` is not adopted:
preliminary Apple App Store and Google Play checks show an active dating product
using the exact Siren name, creating direct category confusion. ConvoCoach
remains the working name until a distinct candidate receives store, domain, and
formal trademark clearance.

## 2026-07-27: Runtime identity and AI spend stay server-owned

Production sign-in uses mobile Authorization Code with PKCE plus server-side
asymmetric OIDC/JWKS verification. The mobile app stores credentials only in the
platform secure store and never contains an OpenAI key. Terra calls reserve an
allowance through a content-free, idempotent server ledger before provider
execution. Client plan claims cannot activate Plus; only a verified server
entitlement can. Store purchase remains disabled until Apple/Google receipts and
webhooks can be verified. This prevents a UI toggle or replayed request from
creating unauthorized paid usage.

## 2026-07-29: GLM-5.2 is the cost-priority hosted provider

The development runtime now defaults to Z.ai-hosted `glm-5.2` through a
server-only adapter. The decision favors lower token cost while preserving
Terra as an explicitly configured rollback path. Z.ai JSON mode is only a
transport aid: independent Pydantic validation, evidence checks, deterministic
safety assessment, safe finish-reason mapping, consent, quotas, and budget
ceilings remain mandatory. The API key and pseudonym secret stay in macOS
Keychain and never enter Flutter, Git, logs, or response payloads. No live call
or production authorization is claimed by this decision.

## 2026-08-06: OpenRouter owns server-side tier routing

The deployment default is now `openrouter_tiered`: welcome/Free allowances map
to `openai/gpt-4o-mini`, while a server-verified Plus entitlement maps to
`openai/gpt-5.6-terra`. One backend credential simplifies qualified model
changes without giving the mobile client provider, model, plan, or key control.
The reservation stores the selected model so usage is charged against its exact
configured token prices even if a plan or deployment configuration later
changes.

OpenRouter requests use strict JSON Schema, requested zero-data retention,
denied provider data collection, and required parameter support. Those routing
flags complement rather than replace ConvoCoach's independent validation,
safety, consent, privacy, cost, and release gates. The legacy direct OpenAI and
Z.ai adapters remain explicit rollback modes; no automatic fallback can create
an unbudgeted second provider call.

## 2026-08-08: Freeze the dating_coach(2) UI for App Store preparation

The current `dating_coach(2)` Flutter interface is the release design baseline.
App Store preparation may add required privacy, accessibility, configuration,
signing, and operational behavior, but it must not silently restyle the product
or copy third-party brand assets. The first release-hardening pass adds an
explicit owner-controlled account export and the required photo-library purpose
copy without changing the navigation or visual design language.

The export uses an authenticated, owner-scoped, versioned backend contract and a
temporary on-device file passed to the platform share sheet. Screenshot bytes,
credential material, identity-provider subjects, transaction hashes, prompts,
and internal request identifiers are excluded. Generated iOS App Store icons are
also rebuilt without an alpha channel and protected by a regression test.

These repository changes do not constitute App Store deployment. Distribution
signing, production API/TLS/database/cache readiness, production Google and
Apple OIDC verification, store products, published legal URLs, independent AI
safety approval, and App Store Connect submission remain separately evidenced
launch gates.

## 2026-08-08: The exact `SIP` rename is rejected during store preflight

The requested conditional rename is not applied. Live Apple and Google store
results already contain multiple `Sip` products, including a social-networking
app published by Sip Inc. and several subscription apps. The short term also
has an established VoIP meaning. Using the exact name would create avoidable
store-search, metadata, and brand-confusion risk, and App Store Connect cannot
authoritatively reserve a replacement name until the paid developer membership
is active. ConvoCoach remains the installed display name while a distinctive
candidate is selected and cleared.

## 2026-08-08: GitHub `main` UI is integrated without production regressions

The vibrant Flutter presentation from GitHub `main` is the current visual
baseline. Its splash, onboarding, Home, five-position navigation shell, shared
background, brand, buttons, cards, color roles, typography, and compatible
conversation surfaces are integrated on top of the complete production branch.
Production-only authentication, import review, analytics, privacy export,
operator metrics, AI routing, billing boundaries, and release controls remain
authoritative where the two histories conflict.

The imported ambient helpers run once instead of looping indefinitely. Normal
interaction durations remain between 150 and 300 milliseconds, system and
in-app reduced-motion preferences produce the same final content without
interpolation, and the central Create destination opens the production import
sheet rather than replacing a navigation branch. Replit-only metadata and
attached design-reference artifacts are not part of the product checkout.

This integration is a tested local release candidate, not evidence of App Store
deployment. Apple Distribution membership/signing, a production TLS backend,
production OIDC, verified store products, published legal URLs, and independent
AI-safety approval remain external launch gates.
