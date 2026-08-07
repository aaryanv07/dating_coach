# AI Coaching Foundation Architecture

## Status

Phase 8 establishes provider-neutral architecture only. The runtime feature flag
defaults to disabled, no route or mobile UI can invoke it, and the only provider
implementation is a deterministic mock that returns a structured placeholder.
No coaching, scoring, interpretation, recommendation, reply, first message,
summary, profile, or compatibility capability exists.

## Boundary

The AI layer may consume only:

- an explicitly reviewed `conversation-events.v1` sequence;
- accepted canonical event structure;
- deterministic `conversation-analytics.v1` metrics;
- event and relationship UUID evidence;
- metric quality and stable missing-data reasons; and
- the analytics source and calculation versions.

It must never consume screenshots, image bytes, OCR output, extraction
intermediates, source paths, device logs, participant names, hidden or rejected
events, soft-deleted events, deleted markers, edit markers, or unknown events.
A valid duplicate source is removed before evidence packaging. Relationships are
packaged only when both referenced events survive minimization.

Phase 8 deliberately does not include message text. A later phase that proposes
content-bearing evidence requires an explicit privacy, retention, consent,
processor, and safety decision; it cannot silently widen this contract.

## Components

```text
reviewed canonical events ─┐
                           ├─ deterministic evidence builder
Phase 6B analytics ────────┘             │
                                         ▼
                              fail-closed safety validator
                                         │
                                         ▼
                             immutable request builder
                                         │
                                         ▼
                           provider protocol / injected mock
                                         │
                                         ▼
                             strict structured parser
                                         │
                                         ▼
                         validated placeholder or safe failure
```

- `contracts.py` owns immutable versioned request, evidence, response, safety,
  and orchestration-result values.
- `evidence.py` performs deterministic, content-minimized projection.
- `safety.py` rejects incomplete review, incomplete or partial timelines,
  missing/unsupported required analytics, missing evidence, unknown-event
  threshold violations, incompatible schemas, and deleted-content
  reconstruction.
- `request_builder.py` creates the immutable provider-neutral request only after
  validation.
- `provider.py` owns the provider protocol and local deterministic mock. It
  contains no HTTP client, external SDK, secret, model name, or service config.
- `response_parser.py` uses strict JSON parsing, exact keys, version checks,
  closed status values, UUID validation, and content-safe exceptions.
- `orchestration.py` is the only provider-call path. It checks the feature flag
  before packaging evidence and returns stable disabled, rejected, processing
  failure, or completed results.

## Prompt contract

`AIPromptTemplateV1` is a descriptor containing a stable identifier, semantic
template version, locale, and declared input slots. It contains no prompt text
and no coaching or business logic. A future prompt catalog must remain local,
immutable, versioned, localizable, reviewed, and separately authorized.

Prompts, rendered prompts, evidence payloads, raw provider responses, message
text, screenshots, OCR, participant names, and provider exceptions must never
be logged. Stable request IDs, contract versions, outcome codes, and aggregate
timing may be considered later only after a logging policy is approved.

## Safety and failure behavior

The default `maximum_unknown_events` is zero and is always explicit in the
requirements contract. The validator requires the deterministic
`structure.unknown_events` metric so the threshold cannot become an implicit
heuristic. Required analytics are named by identifier and must be present,
supported, and non-null.

Provider exceptions become `provider_failure`. Malformed, mismatched, or
over-referencing responses become `invalid_provider_response`. Neither failure
includes provider content or exception details. The parser never logs or echoes
the raw payload.

## Feature and ownership limits

`AI_COACHING_ENABLED=false` is the safe default. Phase 8 adds no public API,
database table, migration, persistence, queue, job, cache, analytics transport,
network client, external processor, backend route, or UI. Route handlers must
never call a provider directly; any later transport must preserve the
orchestration and repository abstractions.

Phase 6A.3 physical Android and iOS qualification remains blocked and mandatory
before production release.

## Phase 9 structured response boundary

Phase 9 adds the provider-independent `ai-coaching-response.v1` contract
documented in `AI-Coaching-Response-Schema.md`. It sits above Phase 8 but does
not call the orchestrator or provider protocol. The only producer is a local
deterministic placeholder generator used for contract, parser, projection, and
future renderer integration tests.

Responses contain closed capability/status values, structural evidence links,
allowlisted localization keys, evidence-sufficiency descriptors, safety codes,
and provenance versions. Strict validation rejects any reference outside the
exact minimized Phase 8 evidence package. The JSON codec uses exact section keys
and rejects content-bearing field names. There is still no AI execution, prompt
execution, response transport, customer UI, or generated guidance.

## Phase 10 execution integration

`AI-Execution-Pipeline.md` defines the default-off coordinator that assembles the
deterministic analytics, Phase 8 evidence/request/mock-provider boundary, Phase 9
structured response, validation, and renderer projection. Every stage remains
injectable and independently testable. The coordinator derives deterministic
UUIDv5 lifecycle identifiers and returns content-free ordered diagnostics.

Both execution and mock flags default off, and the coordinator rejects any
provider identifier other than the existing mock. Cancellation and timeout are
available at stage checkpoints and around the asynchronous provider operation.
No API, caller, prompt execution, external provider, coaching, or UI is added.

## Phase 11 vertical-slice boundary

Phase 11 authorizes one owner-bound, consent-gated API caller and one Flutter
placeholder renderer. The caller reuses the Phase 10 coordinator and accepts no
client prompt, provider, model, event sequence, analytics, evidence, or response.
Only persisted confirmed canonical events enter the service, and only the
existing deterministic mock provider is reachable.

The mobile transport contains localization keys, version facts, ordered section
status, structural reference counts, explicit mock provenance, and stable safe
errors. It contains no evidence payload, raw analytics, conversation content, or
generated coaching. Both backend flags and the build-time mobile entry gate
default off. See `Conversation-Coach-Vertical-Slice.md`.

## Phase 12 provider abstraction boundary

Phase 12 inserts a closed registry and mock-exclusive factory between the
execution coordinator and `AIProvider`. Immutable metadata describes request and
response schema compatibility, structural capabilities, language, existing
feature flags, lifecycle, visibility, and mock/production classification.

The only active registration is `mock-ai-provider.v1`. Future production
metadata must remain inactive, and no production adapter exists. Selection is
deterministic with no fallback; health is derived structurally without a
network probe. The Phase 11 service accepts no provider choice and its public
transport remains unchanged. See `AI-Provider-Architecture.md`.

## Phase 13 operational boundary

The production settings validator requires both backend AI flags to remain
false. The Flutter release validator requires the Coach preview and mock mode
to remain false and forbids an embedded access token. Operational health checks
probe infrastructure only; they never call the mock or a future provider.
Phase 13 adds no coaching, recommendation, generation, score, provider, SDK,
network request, or persistence.
