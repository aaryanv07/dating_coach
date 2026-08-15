# AI Conversation Execution Pipeline

## Status

Phase 10 integrates the Phase 6B, Phase 8, and Phase 9 deterministic boundaries
into one default-off execution coordinator. It is an internal architecture
fixture. There is no public API, mobile caller, provider network, persistence,
prompt execution, or customer-facing AI.

Both `execution_enabled` and `mock_enabled` default to false. Even when tests
enable both flags, the coordinator accepts only provider identifier
`mock-ai-provider.v1`.

## Ordered stages

```text
received
  → response-version negotiation
  → deterministic analytics
  → minimized evidence
  → request safety
  → immutable provider request
  → deterministic mock provider
  → provider placeholder parser
  → deterministic structured-response generator
  → strict structured-response codec/parser
  → structured-response validation
  → content-free renderer projection
  → completed
```

Every stage is injected or isolated behind a typed protocol or small class. The
coordinator never skips a successful prerequisite. A failing or interrupted
stage returns immediately and no downstream diagnostic is recorded.

## Execution identity

No random or wall-clock identifier is created. The execution UUID is UUIDv5 of:

- the explicit request UUID;
- prompt descriptor identifier; and
- prompt descriptor version.

The evidence-package and response UUIDs are separate UUIDv5 derivations of the
execution UUID. Equal inputs produce equal identities and results. Changing the
request UUID or prompt descriptor changes the derived context.

## Contracts

`AIExecutionRequestV1` is content-free and contains the explicit request UUID,
requirements, prompt descriptor, intent, and accepted response versions.
Reviewed canonical source input is supplied separately to avoid embedding
sensitive conversation data in lifecycle contracts.

`AIExecutionContextV1` contains only the three derived UUIDs. Diagnostics contain
only a zero-based sequence, closed stage, closed status, and schema version.
Completed results contain the renderer projection. Failures contain stable
failure codes and, when applicable, the already content-free Phase 8 safety or
Phase 9 response-validation failures.

## Cancellation and timeout

`AIExecutionControl` provides deterministic interruption checkpoints before
every stage. `AIExecutionAwaiter` also wraps construction and awaiting of the
provider operation, so a future deadline or cancellation controller can stop an
in-flight await without changing the coordinator. The Phase 10 default awaiter
is a direct pass-through and uses no clock. Tests inject content-free
cancellation and timeout signals.

Cancellation and timeout produce their own execution state, failure code, and
final diagnostic status. Exception details are never returned.

## Fail-closed behavior

Execution stops for:

- either disabled feature flag;
- unsupported structured-response version;
- deterministic analytics failure;
- incomplete review, unsupported required analytics, missing evidence, schema
  mismatch, or another Phase 8 safety failure;
- missing or non-mock provider;
- provider exception or malformed/mismatched provider placeholder;
- cancellation or timeout;
- strict structured-response parse failure;
- Phase 9 evidence/version/capability/localization validation failure; or
- response version mismatch.

No fallback invents analytics, evidence, provider output, response content, or a
renderer projection.

## Diagnostics and privacy

Diagnostics never contain prompts, evidence payloads, conversation text,
screenshots, OCR, source metadata, participant names, deleted content, response
JSON, exception details, or device facts. The coordinator does not log. Raw
provider and structured-response payloads remain inside strict parsers and are
not attached to failures.

The structured mock still contains only Phase 9 placeholders and marks all real
coaching capabilities unavailable. AI execution, prompt execution, advice,
recommendations, scoring, replies, first messages, summaries, and external
providers remain absent.

## Phase 11 authorized caller

Phase 11 adds the first bounded caller without changing the pipeline. The
owner-bound preview service constructs one fixed `AIExecutionRequestV1`, supplies
the accepted persisted canonical timeline separately, and invokes this
coordinator exactly once. Route code never calls the provider, analytics engine,
evidence builder, response generator, or projector directly.

The service maps only the validated renderer projection into
`conversation-coach-preview.v1`. It does not expose diagnostics, the provider
placeholder, evidence packages, raw analytics, safety internals, or response
JSON. Both `AI_COACHING_ENABLED` and `AI_MOCK_EXECUTION_ENABLED` default false,
and the caller adds no persistence, queue, background task, retry, external
provider, or genuine coaching.

## Phase 12 registry integration

The authorized Phase 11 caller now supplies the coordinator with the Phase 12
mock-exclusive factory instead of directly constructing the mock. At the
provider stage, the coordinator derives a content-free selection request from
the accepted execution contract: request/response schema versions, structural
capabilities, and language.

The registry, deterministic selection policy, compatibility validator, and
structural health evaluator must all accept the registration before the factory
returns an instance. A rejection maps to the existing
`provider_unavailable` failure. The coordinator then retains its exact mock
identifier check as defense in depth.

Direct provider injection remains only as an internal deterministic test seam
for provider failure, malformed response, cancellation, and timeout coverage;
it is mutually exclusive with the factory. No client or mobile provider
selection, production adapter, SDK, network call, prompt execution, or response
contract change is introduced.

## Phase 13 runtime boundary

Production configuration cannot enable this coordinator or its deterministic
mock. Application startup and readiness do not construct the provider factory,
execute the coordinator, or contact an AI service. Correlation IDs are now
request-scoped random or caller-supplied canonical UUIDs for operational
traceability; the deterministic internal execution identities remain unchanged.
