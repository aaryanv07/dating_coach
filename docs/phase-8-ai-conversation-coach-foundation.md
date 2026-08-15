# Phase 8 — AI Conversation Coach Foundation

## Outcome

Phase 8 implements a disabled-by-default, provider-neutral backend architecture
for future AI orchestration. It does not implement customer-facing AI behavior.
The only injectable provider is a deterministic local mock whose response is a
schema-validated foundation placeholder.

## Implemented

- immutable versioned context, evidence, prompt-descriptor, request, response,
  safety-failure, processing-failure, and orchestration-result contracts;
- deterministic evidence packaging from reviewed canonical events and Phase 6B
  analytics;
- structural event and relationship UUID evidence with content-bearing fields
  removed;
- explicit required-metric and unknown-event-threshold requirements;
- fail-closed validation for review, timeline, quality, schema, evidence,
  unknown-event, and deleted-content reconstruction conditions;
- provider protocol and injectable deterministic mock;
- immutable request builder and strict standard-library JSON response parser;
- feature-gated orchestration with safe provider and parser failures; and
- `AI_COACHING_ENABLED=false` environment configuration.

## Privacy proof

The packaged event representation contains only UUID, position, type, speaker,
and whether a timestamp is exact. It excludes text, raw timestamp text, source
image indices and regions, OCR and classifier confidences, metadata, bytes,
paths, hashes, screenshots, participant names, and device facts. Unknown,
deleted, edited, pending-review, soft-deleted, and duplicate-source events are
excluded. Metric projections contain only identifier, value, unit, evidence
UUIDs, and deterministic quality metadata.

No Phase 8 module logs. Provider and parse failures expose stable codes only.
There is no external network or data processor.

## Focused verification

Run from `backend/`:

```bash
.venv/bin/ruff format --check app/ai app/core/config.py tests/test_config.py tests/test_phase8_ai_foundation.py
.venv/bin/ruff check app/ai app/core/config.py tests/test_config.py tests/test_phase8_ai_foundation.py
.venv/bin/mypy app/ai app/core/config.py tests/test_config.py tests/test_phase8_ai_foundation.py
.venv/bin/pytest -W error tests/test_phase8_ai_foundation.py tests/test_config.py
```

The focused suite covers immutability, deterministic packaging, excluded
content, exact metric scoping, disabled behavior, mock success, incomplete
review, timeline gaps, partial input, deleted-content reconstruction, explicit
unknown thresholds, missing metrics, provider exceptions, malformed responses,
strict keys, and non-disclosure of sensitive payloads.

## Verification result

The final Phase 8 regression passed:

- Ruff formatting and linting plus strict MyPy across 54 backend source files;
- all 71 backend tests, including 14 Phase 8 tests;
- `pip check`;
- source-scoped Dart formatting, clean Flutter analysis, and all 90 Flutter
  tests;
- the provider-neutral Phase 6A reference benchmark;
- the Android release AAB build (74.6 MB);
- Docker Compose configuration validation;
- a fresh isolated PostgreSQL upgrade, downgrade to `20260714_0003`,
  re-upgrade, drift check, and current-head check;
- route-boundary, external-provider/network, logging, and privacy-field scans;
  and
- `git diff --check`.

The first mobile formatting invocation traversed two generated build-tool files
and reported unresolved lint configuration before `flutter pub get`; it was not
accepted as evidence. After package resolution, source/test/tool formatting was
unchanged, analysis and tests passed, and generated build output remained
outside the tracked diff. The first dependency check used a nonexistent
root-level virtual-environment path; the authoritative rerun used
`backend/.venv` and passed.

## Explicit exclusions

Phase 8 adds no real coaching, reply or first-message drafting, summary,
conversation DNA, score, recommendation, compatibility, attraction, personality,
health or interest interpretation, prompt content, GPT/OpenAI integration,
external provider, HTTP request, API endpoint, persistence, migration, job,
cache, dashboard, mobile UI, analytics formula, analytics transport, OCR change,
event-model change, payment, subscription, or production release behavior.

Phase 6A.3 remains `BLOCKED`; physical-device qualification is deferred but
still mandatory before release. No commit or push is part of this phase.
