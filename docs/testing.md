# Testing and Verification

Run backend checks from the repository root unless a working directory is noted.

```bash
ruff format --check backend
ruff check backend
```

Run typing and tests from `backend/`:

```bash
mypy app tests
pytest
alembic upgrade head
alembic check
```

Validate local infrastructure without starting containers:

```bash
docker compose --env-file .env.example config --quiet
```

Run these from `apps/mobile/`:

```bash
flutter pub get
dart format .
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter build bundle --release
```

The backend suite covers liveness/readiness configuration, environment parsing,
design-token validity, token-verifier behavior, schema constraints, user/profile
preferences, append-only consent, conversation ownership, message validation,
conversation deletion, and account-deletion cleanup. API integration tests use
isolated SQLite databases with foreign keys enabled. Alembic upgrade, drift
check, downgrade, and re-upgrade are also verified locally against PostgreSQL;
CI runs upgrade and drift checks against PostgreSQL 16.

The Phase 2 Flutter suite covers onboarding progression, the mandatory privacy
and age gates, mock authentication, bottom navigation, central create sheet,
light/dark tokens, state controllers, reduced motion, 200 percent text scaling,
touch targets, semantics, skeleton behavior, and empty/error/offline states.
The Phase 3 suite adds DTO round trips, mock API/repository contracts, Riverpod
state, profile save/navigation, conversation listing/deletion, and large-text
coverage for the new profile flow.

The Phase 4 backend suite adds confirmation consent, ownership, readiness bounds,
source-disposal validation, normalized message persistence, reopen behavior, and
the absence of screenshot-content columns. The Flutter suite adds screenshot and
paste import, mock OCR, source jumping, editor history, merge, split, speaker
swap, duplicate, move, delete/restore, readiness, normalization, temporary-source
cleanup, mock persistence, list/reopen navigation, semantics, 44-pixel actions,
and 200 percent text scaling in Review Studio.

The Phase 5 Flutter suite uses synthetic images and recognized-text structures
to cover orientation, resizing, contrast, metadata removal, memory limits, ML Kit
mapping, temporary-file cleanup, geometry grouping, speaker ambiguity,
locale-aware timestamps, screenshot ordering, timeline warnings, overlap
deduplication, low-confidence review, canonical normalization, Review Studio
integration, idempotency, bounded retries, cancellation, and screenshot cleanup.
The backend suite validates content-free extraction provenance and rejects raw or
unexpected metadata. Native recognition quality still requires physical-device
benchmarking; host tests do not invoke ML Kit method channels.

Phase 6A adds generated original screenshot fixtures, structured ground truth,
accuracy and correction metrics, confidence calibration, report privacy,
unsupported-format handling, cancellation, cleanup, failure capture, and native
integration entry points. Run its provider-neutral reference benchmark from
`apps/mobile/`:

```bash
dart run tool/generate_phase6a_fixture_catalog.dart
flutter test benchmark/phase6a_reference_benchmark_test.dart --reporter expanded
```

This writes content-free JSON and Markdown summaries under
`build/phase6a-benchmark/reference`. It validates the harness and deterministic
extraction strategies, not native OCR quality. Physical Android and iOS commands
and the gates required before Phase 6B are documented in
`docs/phase-6a-native-extraction-qualification.md`.
CI runs the reference benchmark and release bundle separately from the normal
Flutter test suite; native device runs remain a release qualification activity.

## Phase 6A.2 native-readiness verification

Phase 6A.2 adds a strict v2 benchmark schema, session recording, explicit
PASS/BLOCKED evaluation, device/tool capability detection, native runner
selection, comparison/regression export, cancellation outcome coverage, and
unsupported-platform handling. The synthetic catalog expands from five to seven
original fixtures and now measures typed-event classification for emoji,
reaction, media, deleted, date, encryption, and unread items.

Run from `apps/mobile`:

```bash
flutter test test/phase6a2_native_readiness_test.dart
flutter test benchmark/phase6a_reference_benchmark_test.dart --reporter expanded
dart run tool/run_phase6a2_native.dart
```

The final command exits 2 when prerequisites are absent and writes truthful
content-free readiness evidence under `build/phase6a-readiness`. It must not be
reported as a failed benchmark because no native benchmark was attempted. A
successful physical run writes a schema-validated report under
`build/phase6a-benchmark/<platform>`. Compare repeated runs with
`tool/compare_phase6a_benchmarks.dart` before accepting qualification evidence.
The full procedure and regression thresholds are in
`docs/phase-6a2-native-device-readiness.md`.

## Phase 15 freemium and subscription verification

Phase 15 adds immutable plan definitions, integer-minor-unit INR reference
prices, exact allowance limits, reset metadata, protected non-paywalled
capabilities, deterministic exhaustion decisions, and invalid/live-purchase
configuration rejection. Mobile tests cover Settings navigation, monthly/yearly
preview copy, explicit purchase unavailability, and 200 percent text scaling.

No test invokes a store, payment network, receipt service, external AI provider,
or live entitlement. See `docs/phase-15-freemium-subscription-foundation.md` for
focused commands and exclusions.

## Phase 6A.3 physical qualification attempt

The Phase 6A.3 attempt on 2026-07-15 reran the unchanged common native runner.
It returned expected exit code 2 before benchmark execution: Android lacked the
SDK and a physical device; iOS lacked complete Xcode, CocoaPods, and a physical
device. Zero native runs and zero physical accessibility smoke checks were
performed. This is a prerequisite `BLOCKED` result, not a native benchmark
failure or release qualification.

The provider-neutral seven-fixture benchmark still passed every non-native gate
and its self-comparison reported `NO_REGRESSION`. The wider regression pass also
completed 82 Flutter tests, 43 backend tests, a clean release bundle, isolated
Alembic upgrade/downgrade/re-upgrade/drift verification, and the documented
static privacy and artifact scans. See
`docs/phase-6a3-physical-native-qualification.md` for the exact evidence and
remaining gates. Phase 6B must not start while this result is `BLOCKED`.

That sentence records the sequencing rule at the time of the Phase 6A.3 report.
A later user-authorized decision permits build phases to continue with their
automated checks while keeping every missing physical gate explicit and
mandatory before production release.

Subsequent toolchain setup installed Android Studio 2026.1.2, Android API and
Build Tools 36, ADB/platform tools 37.0.0, NDK 28.2.13676358, CMake 3.22.1, and
CocoaPods 1.17.0. A 2026-07-21 follow-up installed and selected Xcode 26.6 and
the iOS 26.5 runtime. `flutter doctor -v` reports no issues, and the content-free
readiness detector blocks both platforms only on their missing physical devices.

The 2026-07-22 simulator follow-up moved Android to AGP 8.13.2 and Gradle 8.13,
aligned the two legacy native-plugin library subprojects to compile SDK 36, and
raised the application minimum SDK from 23 to 24 because the selected
`image_picker_android` dependency requires API 24. The debug APK and release
AAB build. The release shrinker ignores only absent optional non-Latin ML Kit
recognizer namespaces; the application continues to instantiate the bundled
Latin recognizer. Two unchanged Android 16/API 36 ARM64 emulator runs completed
every synthetic ML Kit case with zero failure or cancellation and compared as
`NO_REGRESSION`, but the reports remain `BLOCKED` by the nonphysical run and the
documented native
accuracy-gate misses. A debug iOS simulator compile passes, but installation on
the Apple-silicon iOS 26.5 simulator fails because the current ML Kit
dependencies produce an x86_64-only simulator artifact. Separate unsigned arm64
physical-iPhone debug and release target compiles pass. Xcode has an Apple
account and Personal Team configured; physical signing, installation, and
execution still require a connected iPhone.

## Phase 6A.1 conversation-event verification

The Phase 6A.1 backend suite verifies event and relationship constraints,
ownership-hiding 404s, consent, metadata bounds and prohibited fields, atomic
replacement, relationship references, legacy read-time projection, unchanged
message rows, and deletion cascades. The Flutter suite verifies the complete
event/relationship vocabulary, reaction-versus-emoji classification, target
attachment, date preservation, unknown fallback, event-aware message counting,
deterministic normalization, DTO round trips, and Review Studio corrections.

Migration verification must run upgrade, downgrade to `20260714_0003`, re-upgrade
to head, and `alembic check` against PostgreSQL. The Phase 6A reference benchmark
includes the compact-heart reaction regression and must still pass. Native
Android/iOS OCR and classifier quality are not established by host tests and
remain required physical-device qualification.

## Phase 6B deterministic analytics verification

Phase 6B adds a pure backend domain engine and immutable v1 contracts. It has no
mobile UI, API route, persistence, cache, database migration, AI provider, OCR
change, or native qualification behavior. The canonical catalog and formulas
are in `docs/Analytics-Specification.md`.

The focused backend suite verifies exact metrics, accepted-event inclusion,
pending/rejected/partial handling, duplicate exclusion, deleted and structural
markers, reactions, explicit/orphan replies, literal-question rules, missing or
estimated timestamps, missing speakers, timeline gaps, invalid relationships,
quality metadata, evidence UUIDs, contract versions, immutability,
equal-input/equal-output behavior, privacy, zero engine logging, and a 5,000-
event synthetic case.

Run the focused tests and separate content-free performance benchmark from
`backend/`:

```bash
.venv/bin/pytest -W error tests/test_phase6b_deterministic_analytics.py
.venv/bin/python -m benchmarks.phase6b_analytics_benchmark
```

The benchmark prints aggregate version, event-count, iteration, elapsed-time,
and throughput values only. It is separate from the Phase 6A OCR benchmark and
is not a native performance gate.

Phase 6A.3 remains `BLOCKED`; physical Android/iOS OCR, performance, cleanup,
cancellation, and accessibility qualification are still mandatory before
release even while later build phases proceed.

The final Phase 6B regression passed all 56 backend tests, strict MyPy across 47
source files, Ruff, `pip check`, all 82 Flutter tests, the provider-neutral
Phase 6A reference benchmark, the release bundle, the fresh PostgreSQL
upgrade/downgrade/re-upgrade/drift cycle, and the documented repository scans.
The first drift attempt used a stale pre-existing local database volume and was
not treated as valid evidence; the clean isolated database result is the
authoritative migration verification.

## Phase 7 conversation-data dashboard verification

Phase 7 adds a Flutter-only read-only consumer of supplied Phase 6B analytics.
It adds no backend route, migration, database behavior, analytics persistence,
formula implementation, AI, scoring, coaching, or generation.

Run its focused suite from `apps/mobile/`:

```bash
flutter test test/phase7_dashboard_test.dart
```

The suite covers immutable mapping, exact version acceptance, unsupported
versions, missing required metrics, value/unit and availability validation,
loading, empty and unsupported-data states, timeline-gap presentation,
unsupported metrics with textual reasons, data-quality summaries, content-free
developer evidence, screen-reader labels, and 200 percent text on a compact
phone. Test repositories supply original synthetic structural identifiers and
values; no live backend, network, real conversation, screenshot, OCR provider,
or model is used.

The complete Flutter regression, Phase 6A reference benchmark, release bundle,
backend checks, migration cycle, infrastructure validation, and privacy/boundary
scans remain required. Physical Android and iOS qualification remains a separate
blocked production release gate.

The final Phase 7 regression passed all 90 Flutter tests (including eight
focused dashboard tests), clean Flutter analysis, the provider-neutral Phase 6A
reference benchmark, the rebuilt Android release AAB, all 56 backend tests,
strict MyPy across 47 source files, Ruff, `pip check`, Docker Compose validation,
the isolated PostgreSQL upgrade/downgrade/re-upgrade/drift cycle, release-member
privacy scanning, source boundary scanning, and `git diff --check`.

## Phase 8 AI foundation verification

Phase 8 adds backend-only immutable contracts, content-minimized evidence
packaging, safety validation, provider and prompt abstractions, a deterministic
mock, strict response parsing, and disabled-by-default orchestration. It adds no
route, migration, persistence, external network, model, job, or customer UI.

Run from `backend/`:

```bash
.venv/bin/pytest -W error tests/test_phase8_ai_foundation.py tests/test_config.py
```

The focused suite verifies deterministic and immutable contracts, content
exclusion, event filtering, exact metric selection, default-off behavior,
structured mock success, all required fail-closed readiness conditions,
provider containment, strict response validation, and payload non-disclosure.
Full backend formatting, linting, typing, tests, `pip check`, mobile formatting,
analysis, tests, reference benchmark, Android release build, infrastructure,
isolated migration cycle, repository scans, and `git diff --check` remain the
phase completion gate. Physical Android/iOS qualification remains a blocked
production-release gate rather than a host-test substitute.

The final Phase 8 regression passed all 71 backend tests (14 Phase 8 tests),
strict MyPy across 54 source files, Ruff, `pip check`, all 90 Flutter tests,
clean Flutter analysis, the provider-neutral Phase 6A reference benchmark, the
74.6 MB Android release AAB, Docker Compose validation, the fresh isolated
PostgreSQL upgrade/downgrade/re-upgrade/drift cycle, content-boundary scans, and
`git diff --check`. Physical-device evidence was deliberately not claimed.

## Phase 9 structured coaching-response verification

Phase 9 adds no AI execution or customer feature. Its focused backend suite
checks immutable independently versioned response sections, closed capability
and unavailable-result contracts, exact evidence-package references, schema and
version negotiation, safety failures, deterministic placeholder generation,
strict JSON parsing, forbidden-field rejection, content-free renderer
projections, and privacy non-disclosure.

Run from `backend/`:

```bash
.venv/bin/pytest -W error tests/test_phase9_structured_ai_response.py
```

The full backend, mobile, release-build, Phase 6A benchmark, dependency,
infrastructure, isolated migration, privacy/source-scan, and diff gates remain
required before Phase 9 can be reported complete. Physical Android and iOS
qualification remains a separate blocked production-release gate.

The final Phase 9 regression passed all 85 backend tests (14 Phase 9 tests),
strict MyPy across 61 source files, Ruff, `pip check`, all 90 Flutter tests,
clean Flutter analysis, the provider-neutral Phase 6A reference benchmark, the
74.6 MB Android release AAB, Docker Compose validation, the fresh isolated
PostgreSQL upgrade/downgrade/re-upgrade/drift cycle, content-boundary scans, and
`git diff --check`.

## Phase 10 AI execution pipeline verification

Phase 10 focused tests exercise the default-off end-to-end internal coordinator,
strict dependency order, deterministic lifecycle IDs, immutable contracts,
stop-on-first-failure behavior, stage and asynchronous cancellation/timeout
seams, provider and parser containment, response validation, renderer
projection, content-free diagnostics, and privacy non-disclosure.

Run from `backend/`:

```bash
.venv/bin/pytest -W error tests/test_phase10_ai_execution_pipeline.py
```

The complete backend, Flutter, release, benchmark, dependency, migration,
OpenAPI, JSON schema, CI YAML, infrastructure, prohibited-feature, privacy,
logging, and diff checks remain required for phase completion. Physical Android
and iOS qualification remains a blocked release gate.

The final Phase 10 regression passed all 99 backend tests (14 Phase 10 tests),
strict MyPy across 65 source files, Ruff, `pip check`, all 90 Flutter tests,
clean Flutter analysis, release bundle and 74.6 MB AAB builds, the provider-
neutral Phase 6A benchmark, Docker Compose, OpenAPI, tracked JSON, CI YAML,
fresh isolated migration-cycle, prohibited-feature/privacy/logging scans, and
`git diff --check`.

## Phase 11 Conversation Coach vertical-slice verification

Focused backend coverage lives in
`backend/tests/test_phase11_conversation_coach_api.py`. It verifies
authentication, indistinguishable ownership failures, consent, reviewed
persisted timelines, default-off flags, exact/no-store/content-free transport,
determinism, body rejection, ordered projection, and OpenAPI response contracts.

Focused Flutter coverage lives in
`apps/mobile/test/phase11_conversation_coach_test.dart`. It verifies exact-key
and version parsing, allowlisted localization, immutable collections, ordered
sections, distinct server and controller states, loading/cancellation, network
failure, empty and unsupported data, accessible labels, explicit mock/no-
coaching copy, private-content absence, and 200 percent text.

Run:

```bash
(cd backend && ./.venv/bin/pytest -W error tests/test_phase11_conversation_coach_api.py)
(cd apps/mobile && flutter test test/phase11_conversation_coach_test.dart)
```

Phase completion still requires every repository-level backend, Flutter,
release-build, benchmark, migration, schema, CI, privacy, provider/network,
logging, API-boundary, and diff gate. Physical-device qualification remains a
separate blocked release gate.

## Phase 12 provider abstraction verification

Focused backend coverage lives in
`backend/tests/test_phase12_provider_foundation.py`. It verifies default registry
metadata, registration and duplicate rejection, inactive future-provider
containment, mock exclusivity, request/response schema compatibility,
capability and language compatibility, independent feature-flag enforcement,
deterministic selection, immutable contracts, structural lifecycle health,
absence of network/SDK imports, and Phase 10 execution through the
registry/factory path.

The existing Phase 11 Flutter suite adds a Phase 12 regression that rejects a
non-mock provenance identifier and verifies no provider-selection control is
exposed. The Phase 11 API and mobile contracts are otherwise unchanged.

Run:

```bash
(cd backend && ./.venv/bin/pytest -W error tests/test_phase12_provider_foundation.py)
(cd apps/mobile && flutter test test/phase11_conversation_coach_test.dart)
```

The untouched pre-implementation baseline passed 115 backend tests, strict
MyPy, Ruff, `pip check`, Flutter analysis, and 98 Flutter tests in the documented
project environments. One initial MyPy/Pytest invocation used global Python,
which lacked FastAPI; rerunning the same checks through `backend/.venv` passed
before Phase 12 edits. That invocation is an environment-selection baseline
issue, not a repository regression.

Final Phase 12 completion requires the full backend, Flutter, release-build,
Phase 6A benchmark, infrastructure, isolated migration-cycle, OpenAPI, tracked
JSON, CI YAML, privacy/source, dependency, and diff gates. Physical Android and
iOS qualification remains a separate blocked production-release gate.

The final Phase 12 regression passed all 128 backend tests (13 focused Phase 12
tests), strict MyPy across 73 source files, Ruff, `pip check`, all 99 Flutter
tests, clean Flutter analysis and tracked-source formatting, release bundle and
75.5 MB Android AAB builds, the provider-neutral Phase 6A reference benchmark,
Docker Compose validation, OpenAPI generation (14 paths and 45 schemas), 14
tracked JSON files, four CI YAML files, a provider SDK/network capability scan,
default-off flag checks, and `git diff --check`.

A fresh isolated PostgreSQL 16 cycle upgraded through head
`20260715_0004`, downgraded to `20260714_0003`, re-upgraded, and passed
`alembic check`; its project containers and volumes were removed afterward.
Flutter emitted a forward-looking warning that Gradle 8.13 support will
eventually be dropped in favor of 8.14 or newer. The current release build
passed, so this is a known toolchain maintenance item rather than a Phase 12
failure.

## Phase 13 production-readiness verification

Focused backend coverage lives in
`backend/tests/test_phase13_operational_hardening.py`. It verifies fail-closed
configuration, lifecycle transitions, injected startup readiness, dependency
and migration incompatibility, dependency-free liveness, correlation,
allowlisted structured logging, content-safe errors, request-size enforcement,
security headers, trusted hosts, production OpenAPI policy, and the expected
Alembic head.

Focused Flutter coverage lives in
`apps/mobile/test/phase13_release_configuration_test.dart`. It verifies the
valid production release baseline and rejection of local environment, mock
mode, Coach preview, non-HTTPS endpoints, embedded tokens, malformed shared
configuration, and secret-bearing error messages.

Run:

```bash
(cd backend && ./.venv/bin/pytest -W error tests/test_phase13_operational_hardening.py)
(cd apps/mobile && flutter test test/phase13_release_configuration_test.dart)
```

Full completion also requires Ruff formatting/lint, strict MyPy, all Pytest
tests, `pip check`, all Flutter tests and analysis, tracked Dart formatting,
the Phase 6A reference benchmark, production-configured release bundle/AAB and
iOS no-codesign builds, Docker Compose, OpenAPI generation, tracked JSON/YAML,
provider/credential/privacy scans, release-artifact scans, a fresh PostgreSQL
upgrade/downgrade/upgrade/check cycle, and `git diff --check`.

Startup and readiness must be scanned to confirm they do not call Alembic or
perform schema writes. Production AI and mock flags must remain false, and the
closed provider registry must still expose only `mock-ai-provider.v1` as
executable. Phase 6A.3 remains `BLOCKED`; simulator or compile evidence does not
satisfy the physical-device gate.

The final Phase 13 regression passes all 150 backend tests, Ruff, strict MyPy
across 78 files, `pip check`, all 105 Flutter tests, clean Flutter analysis and
tracked-source formatting, the Phase 6A reference benchmark, the
production-configured release bundle, a 75.5 MB unsigned Android AAB, and a
74.0 MB iPhone device release app with code signing disabled.

A real disposable PostgreSQL/Redis startup reports database `ready`, migrations
`compatible`, and Redis `ready`. A separate fresh PostgreSQL 16 cycle upgrades
through `20260715_0004`, passes `alembic check`, downgrades to
`20260714_0003`, re-upgrades, passes again, and is removed with its volumes.
Docker Compose, OpenAPI (14 paths, 45 schemas), 14 tracked JSON files, four
tracked YAML files, release-artifact privacy scans, provider/credential/network
scans, runtime migration-mutation scans, operational logging scans, and
`git diff --check` pass.

Known non-failing toolchain notices are the future Gradle 8.14 requirement,
future Swift Package Manager plugin adoption, and the existing ML Kit
Apple-silicon simulator limitation. Physical-device qualification remains
blocked and was not represented as passed.

## Phase 14 identity and release-qualification verification

Focused backend coverage lives in
`backend/tests/test_phase14_identity_and_release_qualification.py`. It verifies
bounded claims, exact issuer/audience/time policy, asymmetric algorithm policy,
production configuration rejection, fail-closed production verification,
oversized bearer rejection, verified-email-only provisioning, manifest
validation, deterministic gate aggregation, unsigned/dirty/physical/auth
blocking, content-free evidence collection, unsafe-path rejection, and the
unchanged mock-only AI provider registry.

Focused Flutter coverage lives in
`apps/mobile/test/phase14_authentication_boundary_test.dart`. It verifies the
credential-free session contract, production unavailable boundary, release
rejection of mock authentication, and the double opt-in required for debug
preview authentication. The Phase 13 configuration suite now also covers the
new release authentication mode.

Run:

```bash
(cd backend && ./.venv/bin/pytest -W error \
  tests/test_phase14_identity_and_release_qualification.py)
(cd apps/mobile && flutter test \
  test/phase13_release_configuration_test.dart \
  test/phase14_authentication_boundary_test.dart)
(cd backend && ./.venv/bin/python -m app.release.cli \
  ../release/phase14/release-candidate-manifest.example.json \
  --expect-status blocked)
```

Full Phase 14 completion additionally requires all Ruff, MyPy, Pytest, `pip
check`, Flutter format/analyze/test, Phase 6A benchmark, release
bundle/AAB/iOS build, database cycle, Docker, OpenAPI, JSON/YAML,
provider/network/secret/privacy/artifact, and diff checks. The example manifest
must remain schema-valid and `blocked`; production authentication, distribution
signing, physical Android/iOS qualification, clean committed provenance, and
controlled-launch approval are not available.

The final Phase 14 regression passed Ruff, strict MyPy across 86 files, all 165
backend tests with warnings as errors, `pip check`, Flutter formatting across
133 files, clean Flutter analysis, all 110 Flutter tests, the Phase 6A reference
benchmark, production-configured release bundle/AAB, and the iOS device release
build with signing disabled. The AAB is 75,443,771 bytes and unsigned; the iOS
Runner executable is 50,956,016 bytes and unsigned.

A disposable PostgreSQL 16/Redis 7 environment reported database `ready`,
migrations `compatible`, and Redis `ready`. The database upgraded through head
`20260715_0004`, passed `alembic check`, downgraded to `20260714_0003`,
re-upgraded, passed again, and was removed with its containers and volumes.
Docker Compose, OpenAPI (14 paths, 45 schemas), 15 source JSON files, four YAML
files, provider/identity/network/secret/runtime-migration/artifact scans, the
expected blocked manifest report, and `git diff --check` passed.

The future Gradle 8.14 notice, future Flutter iOS Swift Package Manager plugin
notice, and existing ML Kit Apple-silicon simulator limitation remain
non-failing maintenance items. Phase 6A.3 is still blocked.

## Phase 16 GPT-5.6 Terra verification

Backend coverage lives in
`backend/tests/test_phase16_openai_terra_integration.py`. It uses an injected
fake Responses API client and provider, so the suite performs no network request
and incurs no model cost. It verifies the exact model and structured-output
request, `store=False`, reasoning effort, pseudonymous safety identifier,
content minimization and bounds, evidence-reference validation, fail-closed
configuration, separate external-processing consent, exact public transport,
and non-persistence/no-store behavior.

Flutter coverage lives in
`apps/mobile/test/phase16_openai_terra_coach_test.dart`. It verifies exact-key
live response parsing, rejection of extra fields and invalid provenance/usage,
the external-processing disclosure and grant flow, Terra rendering, and large
text accessibility behavior. Existing Phase 11 mock coverage remains mandatory.

Run:

```bash
(cd backend && ./.venv/bin/pytest -W error \
  tests/test_phase16_openai_terra_integration.py)
(cd apps/mobile && flutter test \
  test/phase11_conversation_coach_test.dart \
  test/phase16_openai_terra_coach_test.dart)
```

Focused verification passes five Phase 16 backend tests, nine retained Phase 11
Flutter tests, four Phase 16 Flutter tests, Ruff, strict MyPy, and Flutter
analysis. The complete regression passes Ruff formatting and lint, strict MyPy
across 93 source files, all 180 backend tests with warnings as errors, `pip
check`, Dart formatting across 143 files, Flutter analysis, and all 125 Flutter
tests. The Phase 6A reference benchmark, Docker Compose configuration,
credential-pattern scan, and `git diff --check` also pass. A live provider smoke
request is deliberately unexecuted because no API credential or explicit
billable-test authorization is present.

## Phase 17 runtime integration verification

Phase 17 adds backend tests for atomic reservation/completion/release,
idempotency conflict/in-progress/replay handling, retry bounds, allowance
exhaustion, rate and budget guards, verified Plus selection, content-free status
transport, and the Terra v2 allowance response. Authentication tests cover
strict production policy and injected verified/invalid token decoding. Flutter
coverage verifies OIDC release configuration, fail-closed authentication,
dynamic token retrieval, the exact authenticated consent/create/confirm/event
save sequence, stable server UUID reuse, unreviewed-data rejection, forbidden
payload-field absence, idempotency reuse, and allowance/error rendering.

The launch-experience coverage adds deterministic global Stats aggregation,
explicit reply/plan outcome recording, deleted-conversation pruning, protected
journal round-trip/deletion/schema rejection, no per-conversation score on the
aggregate surface, and large-text/reduced-motion rendering. Authentication
coverage additionally requires a Google-enabled release to configure the Apple
alternative and verifies immutable provider-routing parameters.
Account-action tests verify that sign-out clears protected device data, accepted
account deletion clears both device data and the session, and failed server
deletion preserves both rather than reporting a false success.

Closing verification on 2026-07-27 passed Ruff formatting/lint, strict MyPy over
98 source files, all 187 backend tests with warnings as errors, `pip check`, Dart
formatting, Flutter analysis, all 141 Flutter tests, the Phase 6A reference
benchmark, Docker Compose configuration, shell/plist validation, and `git diff
--check`. PostgreSQL upgraded through `20260727_0005`, passed `alembic check`,
downgraded to `20260715_0004`, and re-upgraded. A production-configured Flutter
bundle and 77.2 MB Android release AAB built successfully. Android still reports
the non-failing future Gradle 8.14 requirement.

The user repaired the login-keychain signing partition without sharing or
storing the password. Direct framework signing then passed. A signed debug
device build exposed an incorrect debug scene-manifest class; after correcting
`UISceneClassName` to `UIWindowScene`, both property lists and the rebuilt app
signature validated. Device console output also confirmed that a debug build
cannot be reopened independently from the iOS Home Screen without Flutter or
Xcode tooling, which is expected Flutter behavior rather than an app crash.

A fresh 76.4 MB signed release build of ConvoCoach `0.2.0 (5)` then installed,
launched independently, and remained present in the device process list. This
is an installation/startup smoke result only. The native OCR physical-device
suite and content-free qualification report were not run, so Phase 6A.3
physical qualification is still not claimed.

A live Terra smoke test remains unexecuted: no OpenAI API key is present. Store
purchase/restore testing is also unavailable because Apple/Google product and
receipt-verification configuration has not been supplied.

## Phase 18 Z.ai GLM-5.2 verification

Backend coverage lives in
`backend/tests/test_phase18_zai_glm_integration.py`. Its injected Chat
Completions client performs no network call and verifies the fixed model, JSON
mode, thinking parameters, minimized request, strict output schema, evidence
references, token accounting, pseudonymous user ID, provider-specific pricing,
v2 consent, exact public provenance, and non-persistent application behavior.
Safety fixtures verify that a detected under-18 romantic scenario never reaches
the provider and that boundary/coercion-style risk requires safety guidance with
no reply draft.

The retained Phase 16 Flutter test now also accepts the exact GLM schema/model/
provider triple and rejects mixed triples. It verifies the updated processor
disclosure, large-text accessibility, and that provider identity is visible on
the generated result. No live Z.ai call is counted as passing until a billed
test key is configured and a synthetic smoke request succeeds.

Run the focused checks with:

```bash
(cd backend && ./.venv/bin/pytest \
  tests/test_phase18_zai_glm_integration.py \
  tests/test_phase16_openai_terra_integration.py)
(cd apps/mobile && flutter test test/phase16_openai_terra_coach_test.dart)
```

## Guided import-flow verification

The streamlined mobile import regressions verify that screenshot selection
automatically prepares the conversation and opens Review without exposing an
OCR/extraction action, technical item types remain progressively disclosed,
blocked confirmation explains the exact missing human check, and successful
confirmation navigates directly to Conversation Coach while preserving saved
conversation reopen behavior. Existing semantic-label, 200 percent text,
temporary-source cleanup, cancellation, offline-save guidance, and reduced-motion
coverage remain part of the full Flutter gate.

On 2026-08-07 Dart formatting, `flutter analyze`, the focused import tests, and
all 174 Flutter tests passed. The signed `0.2.0+5` profile build installed on the
paired iPhone 13 Pro Max, launched directly without attached Flutter tooling,
and its process remained alive after 20 seconds. This is a startup smoke result;
the guided screen sequence is covered deterministically by widget tests and
still needs ordinary hands-on product acceptance on the phone.

```bash
(cd apps/mobile && flutter test \
  test/phase4_import_flow_test.dart \
  test/phase5_review_integration_test.dart)
```

The OpenRouter-enabled iOS debug build initially appeared to crash when opened
from the Home Screen. A direct CoreDevice launch reproduced iOS terminating the
debug Flutter engine with signal 11 because no Flutter tooling or Xcode was
attached. A freshly signed profile build was then installed on the iPhone,
launched once through a direct console, terminated normally, relaunched without
any attached console, and remained alive after 20 seconds while backend
liveness returned 200. This qualifies standalone startup for that local profile
build only; it is not distribution-signing or full physical-device functional
qualification.

The original competitor-informed Home/dock redesign subsequently passed Dart
formatting, Flutter analysis, and all 172 Flutter tests, including quick-menu,
quick-upload, four-space navigation, 200% text, reduced-motion, and dark/light
theme coverage. During installation diagnostics, the local development bearer
token appeared in a process command line; it was immediately rotated in macOS
Keychain, the local backend was restarted, and the phone was rebuilt with the
replacement. The OpenRouter credential was not exposed. The redesigned signed
profile app then launched without Flutter tooling and remained alive after 20
seconds while backend liveness returned 200.

The follow-up Review Studio refresh extends that original visual system to the
post-extraction correction route. Focused Phase 4 and Phase 5 widget coverage
checks the vibrant backdrop, premium review hierarchy, readiness and warning
semantics, event accessibility, 44-pixel actions, screenshot-source access, and
200% text on a compact iPhone viewport. The shared motion suite remains the
reduced-motion gate; decorative reveals resolve to zero duration when motion is
disabled. Regression coverage also verifies that incomplete review and missing
save consent produce visible, specific feedback instead of an inert final
action. Dart formatting, Flutter analysis, and all 172 Flutter tests passed.
The refreshed signed Profile build then installed on the physical iPhone,
launched without attached Flutter tooling, remained alive after 15 seconds, and
observed backend liveness 200. The save-feedback regression subsequently passed
the same 172-test suite and was installed as a new signed Profile build; its
standalone process again remained alive after 15 seconds with backend liveness
200.

The physical save-path investigation found no conversation POST in the local
backend logs even though the installed Profile app contained both the expected
LAN address and `NSAllowsLocalNetworking`. The same Keychain-backed bearer token
returned 200 from the authenticated conversation endpoint on the Mac, isolating
the remaining physical-device failure to phone-side local-network reachability
or permission. Mobile persistence now maps socket, timeout, authentication,
review-contract, and server-rejection failures to distinct content-free user
guidance. The added local-network recovery regression brings the full mobile
suite to 173 tests; a real conversation save remains unverified until the
iPhone Local Network permission is enabled and the POST is observed.

The 2026-08-07 retry found that the Mac had moved from `192.168.1.9` to
`192.168.1.3` and the previous local backend process had stopped. Local launch
scripts now validate and prefer the lowercase Bonjour hostname, allow that
exact host alongside the current numeric address, and retain the numeric
fallback. The stable hostname returned 200 for health and authenticated
conversation-list probes, its configuration regression passed, and the full
mobile suite now contains 174 passing tests. The stable-host signed Profile
build installed and launched independently. The 2026-08-07 iPhone retry then
completed the content-free end-to-end route chain: consent creation returned
201, conversation creation returned 201, confirmation and event persistence
returned 200, the saved detail reopened with 200, external-processing consent
returned 201, and the subsequent coach-preview request returned 200. This
verifies the local physical save-and-analyze transport path for that signed
profile build; it is not App Store distribution qualification.

One explicitly approved synthetic live Z.ai request passed on 2026-07-29. The
content-free result identified provider `zai-chat-completions-glm-5.2.v1`, model
`glm-5.2`, response schema `glm-coach-output.v1`, 1,787 total tokens, and an
estimated cost of USD 0.004773. Request and response content was not printed or
stored.

## Phase 19 production-hardening verification

Focused backend coverage in `test_phase19_production_release.py` verifies the
production-AI-aware v2 release contract, non-bypassable external launch gates,
AI approval/safety/usage evidence, provider-state consistency, and JSON CLI
semantics. `production_privacy_test.dart` verifies the lifecycle privacy shield,
Android backup/cleartext restrictions, the iOS privacy manifest, and complete
iOS file protection.

The final repository-controlled regression passed Ruff formatting/lint, strict
MyPy over 102 source files, all 210 backend tests in a clean hash-locked Python
3.13 environment, `pip check`, Flutter formatting over 148 source/test files,
Flutter analysis, and all 147 Flutter tests. The PostgreSQL 16 migration cycle
passed upgrade/check/downgrade/re-upgrade/check through `20260727_0005`.

The pinned, non-root backend container built and ran as UID/GID 10001. A
staging-mode operational probe reported lifecycle, PostgreSQL, exact migration,
and Redis readiness. The production-configured Flutter bundle, unsigned Android
AAB, and unsigned iOS device app compiled. Packaged Android release metadata
disables backup, device transfer, and cleartext traffic; the iOS app includes
the application privacy manifest. JSON/YAML, secret-pattern, and diff checks
passed.

The Phase 6A reference suite completed seven original synthetic fixtures with
perfect accuracy/review/cleanup metrics but failed the 2,500 ms latency gate at
27,410 ms p95; its host run also cannot satisfy the native-device requirement.
The Apple Development key partition access was repaired with explicit owner
approval. A signed Profile app then installed, launched independently from the
Home Screen, remained alive after detaching Flutter tooling, and received a
successful conversation-list response from the local backend. The physical iOS
benchmark completed all seven fixtures with no extraction failures or
cancellations, 100% cleanup, a passing cancellation probe, 1,191 ms p95 latency,
and native-device evidence. It remains `BLOCKED` because event classification
was 94.76% against 95% and the minimum fixture message extraction result was
80% against 90%. Android hardware is absent.

## OpenRouter tier-routing verification

`backend/tests/test_openrouter_tiered_integration.py` uses an injected client and
synthetic messages. It verifies strict structured-output parameters, denied
provider data collection, requested zero-data-retention routing, context
minimization, pre-network minor blocking, evidence validation, keyed pseudonym
stability, server-plan model selection, and exact model-price accounting. The
existing Phase 16 Flutter suite verifies GPT-4o mini and Terra labels through
OpenRouter, bounded future model slugs, malformed provenance rejection, the v3
processor disclosure, and large-text behavior.

On 2026-08-06 the focused deterministic run passed 23 backend tests and 9
Flutter tests. One explicitly approved synthetic live request then passed for
each tier: GPT-4o mini used 1,106 total tokens at an estimated USD 0.000316, and
GPT-5.6 Terra used 1,142 at USD 0.003027. Both returned the strict OpenRouter
schema. Only content-free metadata was printed; request and response content was
not logged or stored. This verifies connectivity and contracts, not coaching
quality, independent safety approval, or production readiness.

```bash
(cd backend && ../.venv/bin/pytest -q \
  tests/test_openrouter_tiered_integration.py \
  tests/test_phase17_ai_usage_runtime.py \
  tests/test_phase16_openai_terra_integration.py \
  tests/test_phase18_zai_glm_integration.py)
(cd apps/mobile && flutter test test/phase16_openai_terra_coach_test.dart)
```

## 2026-08-08 App Store preparation verification

The owner-controlled export regression verifies authenticated, owner-scoped
serialization, no-store/attachment headers, inclusion of reviewed conversation
events, exclusion of another user's data, and exclusion of credential,
transaction, screenshot, prompt, and internal request fields. Mobile coverage
verifies authenticated transport, bounded response size, missing-token failure,
an explicit disclosure/confirmation flow, platform sharing, deletion of the
temporary export, and preservation of the session and local reflection.

The iOS release-purpose regression verifies the photo-library usage description.
Every generated iOS AppIcon PNG is inspected through its PNG IHDR color type and
must be opaque. On 2026-08-08 Ruff format/check, strict MyPy, and all 242 backend
tests passed. Dart formatting and `flutter analyze` passed, and all 179 Flutter
tests passed from a temporary parenthesis-free path because the installed
Flutter 3.44 toolchain's macOS native-library parser cannot handle `(2)` in the
checkout path. The repository was restored to its original path immediately
after the run.

This verifies repository behavior only. A distribution-signed archive,
App Store Connect upload, production identity and backend endpoints, sandbox
subscription flow, and final review submission are not yet evidenced.

After the conditional `SIP` rename was rejected by live-store preflight, the
unchanged ConvoCoach display name and frozen `dating_coach(2)` UI were rebuilt
as a signed Profile app on 2026-08-08. The 85.9 MB app passed local code-sign
verification, installed on the paired iPhone 13 Pro Max, launched through
`devicectl`, and its standalone process remained alive after 15 seconds. The
refreshed local backend returned liveness 200 through both loopback and the
Bonjour host. This is current-device installation evidence, not Apple
Distribution signing or App Store production deployment.

## 2026-08-08 GitHub UI integration verification

GitHub `main` at `eabc54e` was merged into the complete production line at
`f620d9e` in a clean SSD checkout. Conflicts were resolved by taking the GitHub
visual system and primary surfaces while retaining production authentication,
review, analytics, privacy, AI, billing, and operational behavior. Regression
coverage was updated only where the intended UI copy, theme values, navigation,
and finite motion changed.

`flutter analyze` completed with no issues and all 176 Flutter tests passed. The
suite covers the imported splash/onboarding/Home/navigation presentation,
reduced motion, 200% text, minimum touch targets, production import and review,
privacy controls, tiered model contracts, and dashboard behavior. Ruff
format/check and strict MyPy passed, and all 242 backend tests passed.

The integrated commit then produced an 85.9 MB iOS Profile app signed by the
available Apple Development identity. Strict code-sign verification passed. The
app installed on the paired iPhone 13 Pro Max, launched through `devicectl`, and
its standalone process remained alive after 15 seconds. The new checkout's
local backend returned 200 for loopback and Bonjour health plus an authenticated
conversation-list probe. This verifies the integrated phone installation; it is
not Apple Distribution signing or an App Store deployment.

## 2026-08-09 GitHub UI refresh installation

Remote `main` commit `b205f84` was merged into the production-candidate branch.
It adds a one-shot shimmer to the Home hero and a one-shot ambient scale to the
center Create control; the shared motion implementation prevents indefinite
decoration and preserves reduced-motion behavior. `dart format`, `flutter
analyze`, and all 176 Flutter tests passed.

The resulting 85.9 MB Profile app passed strict code-sign verification,
installed on the paired iPhone 13 Pro Max, launched through `devicectl`, and
remained alive as a standalone process after 15 seconds. The installed source
commit was `f413689`, which contains `b205f84`. This remains development-signed
physical-device evidence rather than App Store distribution qualification.
