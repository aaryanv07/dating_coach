# ConvoCoach

ConvoCoach is a privacy-conscious mobile coaching product for healthier dating
communication. This repository currently contains the verified Phase 1
foundation, the Phase 2 mobile experience foundation, the Phase 3
authentication/consent/data slice, the Phase 4 conversation import and review
slice, the Phase 5 provider-neutral extraction engine, and the Phase 6A native
qualification harness. Phase 6A.1 adds the typed conversation-event runtime,
Review Studio corrections, reversible persistence, and a versioned owner-scoped
event API without replacing the legacy message contract. Phase 6A.2 adds
repeatable native readiness detection, schema-validated content-free benchmark
evidence, regression comparison, and expanded original fixtures; physical
Android and iOS evidence remains outstanding. The 2026-07-22 Phase 6A.3
simulator follow-up keeps the phase truthfully `BLOCKED`. Android now builds on
AGP 8.13.2 and Gradle 8.13; the two released native-plugin subprojects that
still declare API 31 are compiled against API 36, and the application minimum
is API 24 because the selected `image_picker_android` dependency no longer
supports API 23. Two unchanged Android 16 ARM64 emulator runs completed all
seven ML Kit fixtures with zero failure or cancellation and compared as
`NO_REGRESSION`, but several extraction-quality gates failed and emulator
evidence cannot satisfy `native_device_run`. Android debug and release builds
pass; the release shrinker explicitly ignores only the absent Chinese,
Devanagari, Japanese, and Korean ML Kit modules because the application
instantiates the bundled Latin recognizer. An iOS simulator compile succeeds,
but current Google ML Kit pods produce an x86_64-only artifact that iOS 26
Apple-silicon simulators cannot install. The unsigned arm64 physical-iPhone
debug and release targets compile successfully, and Xcode has an Apple account
and Personal Team configured; signing, installation, and physical qualification
still require connected devices. Phase 6B adds an internal deterministic
analytics foundation over accepted canonical events. Phase 7 adds a
version-aware, read-only Flutter conversation-data dashboard foundation for
those supplied metrics, while adding no analytics transport, persistence,
scoring, AI, coaching, or generation. Phase 8 adds a disabled-by-default,
provider-neutral backend foundation with immutable contracts, minimized
structural evidence, fail-closed validation, strict structured parsing, and an
injectable deterministic mock. It adds no customer AI behavior, external
provider, route, persistence, or mobile UI. Phase 9 adds an immutable structured
coaching-response schema, exact evidence-link validation, deterministic
placeholder-only generation, version negotiation, a strict content-safe codec,
and renderer-facing localization/semantic projections. It still adds no AI
execution, advice, transport, or customer UI. Phase 10 adds one default-off
internal coordinator that wires deterministic analytics through the existing
mock provider and validated placeholder renderer projection, with deterministic
execution IDs, content-free diagnostics, cancellation, and timeout seams. It
adds no external provider, prompt execution, API, persistence, coaching, or UI.
Phase 11 adds one authenticated, owner-bound, consent-gated, non-production API
vertical slice and an exact-key Flutter placeholder preview. Both backend flags
and the mobile entry flag default off. The slice reaches only the deterministic
local mock, renders no genuine coaching or generated text, and persists
nothing. Phase 12 adds internal immutable provider metadata, a closed registry,
deterministic compatibility selection, structural health, and a mock-exclusive
factory. It adds no production provider, SDK, network capability, API change,
provider selection UI, persistence, or generated content.
Phase 13 adds fail-closed production configuration, explicit lifecycle and
dependency readiness, privacy-safe correlation and operational logs, safe error
containment, request limits, security headers, production-disabled OpenAPI, and
mobile release configuration validation. It does not deploy the product or
activate AI. Android release builds no longer fall back to debug signing.
Phase 14 adds strict production-authentication contracts and policy, bounded
current-user claim handling, a credential-free mobile authentication boundary,
content-free supply-chain and artifact provenance contracts, and a deterministic
release-gate evaluator. The checked-in qualification manifest is intentionally
`blocked`: no production authentication adapter exists, Android and iOS
artifacts are not distribution-signed, controlled launch is not authorized, and
Phase 6A.3 physical-device qualification remains outstanding. Phase 14 neither
deploys nor submits the product.
Phase 15 adds the approved welcome, Free, and Plus catalog, a pure content-free
allowance evaluator, and a non-purchasing Settings preview. Every plan remains
purchase-disabled; no billing SDK, receipt, route, persistence, entitlement,
quota decrement, external AI call, deployment, or store submission is included.
Phase 16 implements a default-off GPT-5.6 Terra coaching path for development
and staging. It is backend-only, separately consented, strictly structured,
content-minimized, and non-persistent. No API credential is checked in and no
live billable request has been run. Production AI remains blocked until a newly
authorized release qualification is complete.
Phase 17 connects the reviewed-conversation mobile repository to the authenticated
FastAPI API, adds OIDC Authorization Code with PKCE and secure device token
storage, and replaces the production authentication placeholder with strict
asymmetric OIDC/JWKS verification. It also adds server-owned Free/Plus
entitlements, atomic AI allowance reservations, canonical idempotency keys,
rate limits, content-free usage/cost accounting, and fail-closed user/global
budget ceilings. Store purchases remain disabled until Apple and Google receipt
verification credentials and products are configured. No live Terra request has
been made because this workstation has no OpenAI API key in Keychain.
Physical qualification remains blocked and mandatory before release.
Phase 18 adds Z.ai-hosted GLM-5.2 as the cost-priority server-side provider,
with strict JSON/schema/evidence validation, v2 processor consent,
provider-specific budgets, and a separate deterministic safety gate. The local
SSD scripts now select GLM-5.2 and read its key only from macOS Keychain. One
approved synthetic live smoke request passed on 2026-07-29 without logging or
retaining private content. Production release qualification remains blocked.

The current tier-routing update adds `openrouter_tiered` as the deployment
default: welcome/Free users use `openai/gpt-4o-mini`, and server-verified Plus
users use `openai/gpt-5.6-terra`. One backend-only OpenRouter key serves both
models; model slugs and prices remain environment configuration so a qualified
future model can be swapped without a mobile release. Requests use strict
structured output, independent safety validation, zero-data-retention routing,
and denied provider data collection. See
[docs/openrouter-tiered-ai-routing.md](docs/openrouter-tiered-ai-routing.md).

For a Windows primary-development workstation, follow
[docs/windows-development-handoff.md](docs/windows-development-handoff.md).
Windows supports the shared application, backend, tests, Android builds, and
physical Android qualification. The required iOS build, signing, and physical
iPhone qualification remain macOS/Xcode-only.

Phase 19 adds production privacy controls, hash-locked backend dependencies, a
non-root backend image, production AI review attestations, and a v2 release
contract that makes deployment, billing, restore, monitoring, legal/privacy,
signing, and physical-device evidence non-bypassable. See
[docs/phase-19-production-hardening.md](docs/phase-19-production-hardening.md).

The launch-experience pass adds an original premium aggregate Stats dashboard
for user-recorded reply outcomes, self-assessed communication progress, explicit
plan confirmation, and protected private reflection. It never scores an
individual person or predicts interest. See
[docs/Overall-Progress-Dashboard.md](docs/Overall-Progress-Dashboard.md).

## Repository layout

```text
apps/mobile/       Flutter Android/iOS application
backend/           FastAPI service and tests
design/tokens/     Platform-neutral design and motion tokens
docs/              Product, architecture, planning, and testing decisions
.github/workflows/ Continuous integration
docker-compose.yml Local PostgreSQL and Redis services
```

## Local backend

```bash
cp .env.example .env
docker compose up -d
python3 -m venv .venv
.venv/bin/python -m pip install -e "backend[dev]"
(cd backend && ../.venv/bin/alembic upgrade head)
.venv/bin/uvicorn app.main:app --app-dir backend --reload --env-file .env
```

PostgreSQL and Redis bind to loopback on ports `5432` and `6379` by default.
Change `POSTGRES_PORT` or `REDIS_PORT` in `.env` when either port is already in
use.

The service exposes:

- `GET /health/live` for liveness
- `GET /health/ready` for lifecycle, PostgreSQL, migration, and Redis readiness
- `GET /api/v1/subscription/status` for the authenticated server-owned plan and
  allowance snapshot
- `GET /docs` for the generated OpenAPI interface in explicitly enabled
  non-production environments
- `/api/v1` identity, preferences, communication profile, consent, conversation,
  reviewed-import confirmation, message, typed-event, default-off mock Coach
  preview, and privacy-deletion routes

See [docs/phase-6a1-conversation-event-runtime-foundation.md](docs/phase-6a1-conversation-event-runtime-foundation.md)
for the current event-runtime scope,
[docs/phase-6a-native-extraction-qualification.md](docs/phase-6a-native-extraction-qualification.md)
for the outstanding physical-device gate,
[docs/phase-6a2-native-device-readiness.md](docs/phase-6a2-native-device-readiness.md)
for the runner and evidence workflow,
[docs/phase-6a3-physical-native-qualification.md](docs/phase-6a3-physical-native-qualification.md)
for the current blocked physical-execution report,
[docs/Conversation-Event-Spec.md](docs/Conversation-Event-Spec.md) for the event
contract, and [docs/Analytics-Specification.md](docs/Analytics-Specification.md)
for the internal Phase 6B metric catalog and quality rules. See
[docs/phase-7-conversation-health-dashboard.md](docs/phase-7-conversation-health-dashboard.md)
for the Phase 7 presentation boundary. Phase 7 adds no API route, persistence,
score, behavioral interpretation, AI, advice, or generated content; without a
later authorized transport, the default dashboard truthfully shows no analytics.
See [docs/AI-Coaching-Architecture.md](docs/AI-Coaching-Architecture.md) and
[docs/phase-8-ai-conversation-coach-foundation.md](docs/phase-8-ai-conversation-coach-foundation.md)
for the Phase 8 provider-neutral boundary and completion evidence.
See [docs/AI-Coaching-Response-Schema.md](docs/AI-Coaching-Response-Schema.md)
and
[docs/phase-9-structured-ai-response-foundation.md](docs/phase-9-structured-ai-response-foundation.md)
for the Phase 9 response contract and explicit no-coaching boundary.
See [docs/AI-Execution-Pipeline.md](docs/AI-Execution-Pipeline.md) and
[docs/phase-10-ai-conversation-execution-pipeline.md](docs/phase-10-ai-conversation-execution-pipeline.md)
for the Phase 10 default-off mock execution pipeline.
See
[docs/Conversation-Coach-Vertical-Slice.md](docs/Conversation-Coach-Vertical-Slice.md)
and
[docs/phase-11-conversation-coach-vertical-slice.md](docs/phase-11-conversation-coach-vertical-slice.md)
for the Phase 11 transport, security, mobile-state, and no-coaching boundaries.
See [docs/AI-Provider-Architecture.md](docs/AI-Provider-Architecture.md) and
[docs/phase-12-production-provider-abstraction-foundation.md](docs/phase-12-production-provider-abstraction-foundation.md)
for the Phase 12 registry, compatibility, lifecycle, health, factory, and
continued mock-only execution boundaries.
See
[docs/Production-Readiness-and-Operational-Hardening.md](docs/Production-Readiness-and-Operational-Hardening.md)
and [docs/Operations-Runbook.md](docs/Operations-Runbook.md) for the Phase 13
runtime, release, and operator boundaries.
See
[docs/Production-Identity-and-Authentication-Verification.md](docs/Production-Identity-and-Authentication-Verification.md),
[docs/Release-Candidate-Qualification.md](docs/Release-Candidate-Qualification.md),
[docs/Release-Gate-Specification.md](docs/Release-Gate-Specification.md), and
[docs/Controlled-Launch-Runbook.md](docs/Controlled-Launch-Runbook.md) for the
final Phase 14 pre-release boundary.
See
[docs/phase-16-openai-terra-integration.md](docs/phase-16-openai-terra-integration.md)
for the fixed Terra adapter, consent, minimization, configuration, cost, and
remaining launch gates.
See [docs/phase-17-runtime-integration.md](docs/phase-17-runtime-integration.md)
for the authenticated mobile/backend runtime, quota, local setup, completed
verification, and remaining external release dependencies.
See
[docs/phase-18-zai-glm-5-2-integration.md](docs/phase-18-zai-glm-5-2-integration.md)
for the GLM adapter, v2 consent, independent safety layer, configuration, cost
boundary, and remaining live qualification gate.

## Local mobile app

This workstation uses the external-SSD layout documented in
[docs/external-ssd-development.md](docs/external-ssd-development.md). Connect and
mount `ConvoCoachDev` before running the local commands below.

The reproducible SSD-local setup keeps Python, Flutter, Gradle, CocoaPods,
PostgreSQL, Redis, SQLite development data, and build outputs on the external
volume while secrets remain in macOS Keychain:

```bash
./scripts/setup_local_development.zsh
./scripts/configure_local_ai_secrets.zsh
```

Then run the backend and app in separate terminals:

```bash
./scripts/run_local_backend.zsh
./scripts/run_local_mobile.zsh --device-id <flutter-device-id>
```

The phone and Mac must be on the same trusted network. The helper detects the
Mac LAN address, passes only the development bearer credential to the debug app,
and keeps the OpenRouter key and pseudonym secret server-side. Do not use this local
HTTP/development-token path for distribution builds.

Unauthenticated preview flows still use mock, in-memory repositories. When an
authenticated API is configured, conversations use the owner-scoped FastAPI
client and persist only reviewed, confirmed normalized events. Supported Android and iOS
devices use Google ML Kit through a provider-neutral OCR boundary; tests and
unsupported platforms retain deterministic mock OCR. Screenshot bytes remain
temporary and on-device. Review Studio confirmation is required before normalized
conversation events can be saved. OIDC sessions use Authorization Code with
PKCE, store access/refresh credentials only in platform secure storage, and
obtain a fresh access token at request time. The Coach HTTP client and the
conversation repository share that credential boundary.
Phase 12 adds no mobile provider selector, setting, screen, or transport change.
Phase 13 release builds require production mode, an HTTPS API URL, disabled mock
and Coach preview flags, and no compiled API access token.
Release configuration now requires `CONVOCOACH_AUTHENTICATION_MODE=oidc`, an
HTTPS discovery URL, a public mobile client ID, the registered
`com.convocoach.convo-coach:/oauthredirect` callback, and scopes including
`openid`. The external identity tenant and redirect registration are deployment
configuration and are not checked into this repository.
Phase 16 allows that default-off client to render an exact GPT-5.6 Terra
response after a separate external-processing disclosure and consent. Provider
selection and credentials remain server-only, and neither the app nor backend
persists the coaching result. This development/staging path does not override
the release gates above.
Phase 18 additionally accepts only the exact GLM-5.2/Z.ai response provenance,
updates the processor disclosure, and adds an independent pre/post-model safety
gate. See
[docs/phase-18-zai-glm-5-2-integration.md](docs/phase-18-zai-glm-5-2-integration.md).
The current client also accepts the strict OpenRouter response contract and a
bounded server-configured `provider/model` slug. The disclosure identifies
OpenRouter, the underlying tier models, and the requested privacy-routing
controls. Provider/model choice remains server-owned.
Production launch work is documented in
[`docs/Production-Launch-Runbook.md`](docs/Production-Launch-Runbook.md). The
granular gate file at
[`release/phase20/production-launch-evidence.current.json`](release/phase20/production-launch-evidence.current.json)
fails closed until identity/store accounts, deployment, signed device qualification,
legal/privacy review, and independent AI safety approval have current evidence.
