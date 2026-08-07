# Phase 12: Production Provider Abstraction Foundation

## Status

Implemented as a backend-only, mock-exclusive architecture foundation. Phase 12
does not activate production AI.

Phase 6A.3 remains `BLOCKED` pending the required physical Android and iOS
qualification suites.

## Scope delivered

- immutable provider metadata, configuration, selection, compatibility, and
  health contracts;
- an immutable closed provider registry with duplicate and lifecycle
  validation;
- deterministic selection without fallback;
- structural health evaluation without live probes;
- a factory that can instantiate only the existing deterministic mock;
- Phase 10 coordinator integration;
- Phase 11 service wiring through the registry/factory path;
- focused backend registration, factory, compatibility, lifecycle, privacy,
  and pipeline tests; and
- Flutter regressions proving that transport remains mock-only and no provider
  selector is exposed.

## Files

Created:

- `backend/app/ai/provider_contracts.py`
- `backend/app/ai/provider_registry.py`
- `backend/app/ai/provider_factory.py`
- `backend/tests/test_phase12_provider_foundation.py`
- `docs/AI-Provider-Architecture.md`
- `docs/phase-12-production-provider-abstraction-foundation.md`

Modified:

- `backend/app/ai/execution_pipeline.py`
- `backend/app/services/conversation_coach.py`
- `apps/mobile/test/phase11_conversation_coach_test.dart`
- `README.md`
- `docs/AI-System-Architecture.md`
- `docs/AI-Coaching-Architecture.md`
- `docs/AI-Execution-Pipeline.md`
- `docs/testing.md`
- `docs/privacy-and-safety.md`
- `docs/decision-log.md`

## Provider boundary

The default registry contains only `mock-ai-provider.v1`. Future production
metadata is structurally permitted only while inactive. The registry rejects
an active production record, and the factory independently rejects every
non-mock provider.

The execution coordinator builds a content-free compatibility request at the
provider stage. It requires the current request/response versions,
`foundation_placeholder`, the four structural response capabilities, and the
prompt descriptor's language. It does not accept provider selection from the
client.

## Safety, privacy, and security

No provider SDK, network client, endpoint, API key, secret, token, OAuth flow,
certificate, model name, prompt execution, streaming path, retry mechanism, or
live health check was added.

No conversation content, screenshot, OCR, prompt, evidence package, analytics
payload, participant name, raw response, or exception detail enters registry,
configuration, selection, health, or factory contracts.

No API response changed. No customer-facing mobile screen or setting changed.
No data is persisted, and there is no migration.

## Test coverage

Focused backend tests cover:

- registry contents and deterministic order;
- duplicate registration;
- active-production rejection;
- inactive future metadata rejection at creation;
- unsupported identifiers;
- request and response schema compatibility;
- execution and response capability compatibility;
- language compatibility;
- independent feature-flag enforcement;
- deterministic selection;
- mock exclusivity;
- structural lifecycle health;
- immutable metadata and schema validation;
- absence of network/SDK imports; and
- Phase 10 pipeline execution through the registry/factory path.

Focused Flutter regression verifies the exact mock identifier remains required
by transport and that the preview does not expose a provider-selection control.

## Verification record

The untouched pre-Phase 12 baseline passed:

- Ruff formatting and lint;
- strict MyPy in the backend virtual environment;
- 115 backend tests with warnings treated as errors;
- backend dependency validation;
- Flutter formatting and analysis; and
- 98 Flutter tests.

One non-authoritative global-Python invocation could not import FastAPI because
the repository dependencies live in `backend/.venv`. The same MyPy and Pytest
commands passed in the documented project environment before any Phase 12 edit.
This is an environment-selection issue, not a source failure.

Final full-repository verification results are recorded in `docs/testing.md`.

The final gate passed:

- 128 backend tests, including 13 focused Phase 12 tests;
- Ruff formatting/lint, strict MyPy across 73 files, and `pip check`;
- 99 Flutter tests, analysis, and tracked-source formatting;
- release bundle and 75.5 MB Android release AAB builds;
- the Phase 6A reference benchmark;
- Docker Compose validation;
- OpenAPI generation with 14 paths and 45 schemas;
- 14 tracked JSON and four tracked YAML syntax checks;
- provider SDK/network and default-off configuration scans;
- a fresh isolated PostgreSQL upgrade/downgrade/re-upgrade/drift cycle at
  Alembic head `20260715_0004`; and
- `git diff --check`.

Flutter's release build emitted a future-maintenance warning that Gradle 8.13
support will eventually require 8.14 or newer. The current build passed. No
physical-device suite was executed or claimed.

## Explicit exclusions

Phase 12 introduces:

- no external provider initialization;
- no network request;
- no production AI execution;
- no coaching or recommendation;
- no reply or first-message generation;
- no Communication DNA;
- no summary or scoring;
- no persistence or database migration;
- no physical-device qualification; and
- no commit or push.
