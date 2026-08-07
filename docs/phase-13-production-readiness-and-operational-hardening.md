# Phase 13: Production Readiness and Operational Hardening

## Status

Implementation status: complete and verified in the working tree. No commit,
push, deployment, or Phase 14 work is included.

Phase 6A.3 remains `BLOCKED`: neither Android nor iOS physical-device native
qualification has produced the required passing content-free reports.

## Implemented scope

- strict environment parsing and configuration validation;
- production fail-closed rules;
- explicit application lifecycle;
- liveness separated from operational readiness;
- PostgreSQL connectivity, exact Alembic revision, and Redis connectivity
  startup checks;
- request correlation and allowlisted JSON operational logs;
- content-safe unexpected-error containment;
- bounded request bodies;
- security headers and trusted-host enforcement;
- production-disabled OpenAPI;
- Flutter release configuration validation;
- Android release signing no longer falling back to the debug key;
- CI release builds, dependency check, contract validation, and provider scan;
  and
- architecture, privacy, testing, and operations documentation.

## Explicit non-scope

Phase 13 adds no production AI provider, external AI SDK, outbound AI network
call, prompt execution, real coaching, recommendation, reply or first-message
generation, Communication DNA, relationship scoring, AI persistence, database
table, Alembic revision, deployment, or Phase 14 feature.

## Runtime rules

The backend validates settings before accepting the application. Production
requires debug and OpenAPI off, operational checks on, explicit non-local
hosts, secure dependency URLs, no development auth values, non-debug logging,
bounded requests, and both AI flags off.

The process becomes ready only after PostgreSQL responds, its recorded migration
revision exactly matches `20260715_0004`, and Redis responds to the configured
authentication/selection and `PING`. These checks are read-only. Shutdown
disposes the application-owned engine.

Every response carries one opaque correlation UUID and privacy/security headers.
Logs include route templates and content-free operational values only.

## Mobile rules

Release startup requires production environment, HTTPS API URL, mock mode off,
Coach preview off, and no embedded API token. Debug development retains its
local deterministic path. Android release signing can use a complete secure
property set but never falls back to the debug key.

## Test coverage

`backend/tests/test_phase13_operational_hardening.py` covers configuration,
lifecycle transitions, successful and failed startup, readiness, liveness,
correlation, structured log allowlisting, safe failures, request limits,
security/trusted-host headers, production OpenAPI, and the expected Alembic
head.

`apps/mobile/test/phase13_release_configuration_test.dart` covers the valid
release baseline; environment, mock, preview, HTTPS, and embedded-token
rejection; content-free configuration errors; local debug behavior; and
malformed shared configuration.

Existing Phase 10--12 integration tests remain the regression gate.

## Verification record

- Ruff formatting and linting pass.
- Strict MyPy passes across 78 source and test files.
- All 150 backend tests pass with warnings treated as errors.
- `pip check` reports no broken requirements.
- Tracked Dart formatting and Flutter analysis pass.
- All 105 Flutter tests and the Phase 6A reference benchmark pass.
- Production-configured Flutter release bundle and unsigned Android AAB build;
  the final AAB is 75,474,015 bytes (75.5 MB).
- The production-configured iPhone device release app builds with code signing
  disabled; `Runner.app` is 74.0 MB.
- A real disposable PostgreSQL/Redis integration starts ready with database
  `ready`, migrations `compatible`, and Redis `ready`.
- A fresh PostgreSQL 16 database upgrades to `20260715_0004`, passes
  `alembic check`, downgrades to `20260714_0003`, re-upgrades, passes the check
  again, and is removed with its disposable volume.
- Docker Compose, OpenAPI (14 paths, 45 schemas), 14 tracked JSON files, four
  tracked YAML files, provider/credential/network boundaries, startup migration
  mutation, operational logging, release artifacts, and `git diff --check`
  pass.

The Android build emits Flutter's forward-looking warning that Gradle 8.13
support will be removed in a future Flutter release; it is not a current build
failure. The iOS build reports future Swift Package Manager adoption warnings
for existing plugins and the already documented Google ML Kit Apple-silicon
simulator limitation; the arm64 physical-device release target still compiles.

## Completion boundary

- AI execution remains disabled by default.
- Mock execution remains disabled by default.
- `mock-ai-provider.v1` remains the only executable provider.
- No external or production AI provider exists.
- No outbound AI networking exists.
- No genuine coaching or generated content exists.
- No new persistence or schema change exists.
- No migration was created.
- Startup and readiness never apply migrations.
- Phase 6A.3 remains blocked and mandatory before release.
- Work stops before Phase 14 until the Phase 13 report is reviewed.
- No commit or push is performed.
