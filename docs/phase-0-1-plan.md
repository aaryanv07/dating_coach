# Phase 0 and Phase 1 Plan

## Baseline note

At the start of this phase the repository contained an uncommitted README and an
empty, root-level `master-build-prompt.md`. The requested
`docs/master-build-prompt.md` did not exist. The empty file was read completely;
there were no additional requirements to extract from it. This plan therefore
uses the explicit task request and README as its inputs.

## Verification update: 2026-07-14

Flutter 3.44.6 and Dart 3.12.2 became available after the original baseline. The
Android/iOS project was generated in `apps/mobile`, and Phase 1 was re-verified:

- Flutter dependency resolution, formatting, analysis, and the generated widget
  test passed before Phase 2 implementation began.
- Backend formatting, linting, strict typing, all 21 tests, dependency integrity,
  and Docker Compose parsing passed without backend source changes.
- Phase 1 is complete. Phase 2 work is documented separately in
  `docs/phase-2-mobile-foundation.md`.

## Phase 0: product and engineering foundation

Goals:

- Establish permanent product, privacy, safety, design, testing, and engineering
  rules in `AGENTS.md`.
- Record architecture boundaries and the first decision log.
- Define platform-neutral core, light, dark, and motion tokens.
- Make the scope boundary visible: no Phase 2 product features are included.

Acceptance criteria:

- A contributor can identify the product's non-negotiable safety and privacy
  constraints without reading implementation code.
- The repository layout has clear ownership boundaries.
- Initial tokens parse as JSON and define accessible semantic roles for both
  themes.

## Phase 1: runnable service foundation

Goals:

- Add a typed FastAPI application factory and versioned service metadata.
- Add liveness and configuration-readiness endpoints.
- Add local PostgreSQL and Redis services with health checks and local-only port
  binding.
- Add deterministic endpoint, configuration, and token tests.
- Add CI checks for formatting, linting, typing, tests, and Compose validation.
- Create a Flutter application only when the Flutter SDK is available.

Acceptance criteria:

- `GET /health/live` reports that the API process is serving requests.
- `GET /health/ready` returns 200 only when required dependency URLs are present.
- The readiness response does not claim live database or Redis connectivity.
- Available local quality checks pass.
- Missing SDKs or unverified runtime behavior are reported explicitly.

## Explicitly excluded from this phase

- Authentication, accounts, profiles, subscriptions, or analytics
- Database schemas, migrations, repositories, or persisted conversation content
- Redis-backed queues, caching, rate limiting, or sessions
- AI providers, prompt templates, conversation analysis, and generated replies
- Message import, screenshot parsing, notification access, and external app access
- Production deployment, observability providers, and secret management
- Phase 2 implementation of any kind
