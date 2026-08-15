# AI Provider Architecture

## Status and boundary

Phase 12 introduces an internal production-provider abstraction foundation. It
does not introduce a production provider. The deterministic in-process mock
remains the only executable provider, and both existing execution flags remain
off by default.

The implemented call path is:

```text
Conversation Coach service
  -> AI execution coordinator
  -> immutable provider-selection request
  -> closed provider registry
  -> deterministic selection policy
  -> compatibility validator
  -> structural health evaluator
  -> mock-exclusive provider factory
  -> provider protocol
  -> deterministic mock provider
```

The registry, factory, and health model perform no I/O. They contain no HTTP
client, SDK initialization, endpoint, API key, token, credential, certificate,
OAuth flow, prompt text, or provider response content.

## Provider metadata

`AIProviderMetadataV1` is immutable and includes:

- identifier, semantic version, and provider family;
- supported request and response schema versions;
- maximum request and response schema versions;
- execution and structured-response capabilities;
- language metadata;
- required existing feature flags;
- lifecycle state;
- internal visibility; and
- mock or production classification.

Every scalar identifier is non-blank. Version, capability, language, and
feature-flag tuples reject duplicates. The declared maximum schema version must
also appear in the corresponding supported-version tuple.

Metadata is internal. It is not returned by the API or mobile transport.

## Registry and registration

`AIProviderRegistry` accepts immutable metadata registrations at construction
and exposes deterministic insertion-order iteration plus identifier lookup. It
rejects duplicate identifiers and an empty registry.

The registration policy is closed:

- only `mock-ai-provider.v1` may be classified as a mock;
- only that deterministic mock may be active; and
- production-classified metadata must remain inactive.

The default registry contains exactly one record: the active, internal,
deterministic mock. The architecture permits future metadata records, but they
must be inactive and cannot be instantiated.

## Capabilities and compatibility

Phase 12 defines one execution capability:
`foundation_placeholder`. The mock advertises only the existing structural
response capabilities:

- response schema;
- evidence references;
- explanation placeholders; and
- safety notices.

It does not advertise coaching guidance, recommendations, reply drafting,
first-message drafting, Communication DNA, relationship scoring, or
compatibility scoring.

The compatibility validator checks:

- active lifecycle;
- exact mock classification and identifier;
- request schema support;
- overlap with accepted response schema versions;
- required execution capabilities;
- required response capabilities;
- language support; and
- every required feature flag.

Failures are stable content-free codes. They do not expose configuration or
provider internals.

## Selection and factory

Selection is deterministic. An explicit internal identifier is used when
present; otherwise the immutable runtime configuration's default identifier is
used. There is no fallback to another provider and no ranking, load balancing,
random choice, or customer preference.

The factory repeats the mock-only boundary after selection. A provider instance
is returned only when metadata is compatible, structural health is available,
the identifier is `mock-ai-provider.v1`, and classification is `mock`.

The runtime configuration contains only:

- the two existing booleans `AI_COACHING_ENABLED` and
  `AI_MOCK_EXECUTION_ENABLED`; and
- the internal default provider identifier.

It cannot carry secrets, endpoints, model names, authentication, or transport
configuration.

## Lifecycle and health

Lifecycle has two states: `active` and `inactive`. Phase 12 has no activation
workflow. Only the deterministic mock registration is active.

Health is structural and immutable:

- `available`: active mock with all required flags enabled;
- `disabled`: required flags are off;
- `inactive`: registration is inactive; or
- `unavailable`: registration violates the executable mock boundary.

Health evaluation performs no live probe, DNS lookup, socket operation,
authentication, model request, clock sampling, or retry.

## Execution-pipeline integration

The Phase 10 coordinator accepts a provider factory in addition to its existing
direct provider injection seam used by deterministic failure tests. Supplying
both is rejected as ambiguous.

At the provider stage, the coordinator derives an immutable selection request
from the already validated execution request. Factory rejection becomes the
existing content-free `provider_unavailable` execution failure. The coordinator
still verifies the resulting provider identifier before invoking it.

The Phase 11 service uses the factory path. It does not select a provider from
client input, and the public request and response contracts are unchanged.

## Future production integration boundary

A separately authorized future phase may add inactive production metadata
without changing transport or mobile code. Activating any production provider
would still require separate implementation and review of:

- provider adapter and lifecycle ownership;
- secret storage and rotation;
- endpoint and regional processing policy;
- data minimization and processor disclosure;
- network controls and timeouts;
- provider-specific safety review;
- audit and incident response;
- data retention and training controls; and
- updated tests, privacy documentation, and user consent.

None of those production capabilities exists in Phase 12.

## Privacy and security

Provider metadata contains no user data. Selection requests contain contract
versions, closed capabilities, language metadata, and an internal identifier
only. Neither structure carries conversation content, evidence, prompts, raw
responses, participant names, screenshots, OCR, device data, credentials, or
secrets.

No new log, persistence, migration, table, cache, queue, background job, API
route, mobile setting, or customer-visible selector is introduced.

## Known limitations

- No production AI provider exists.
- No external provider can be activated or instantiated.
- Health is structural and does not describe service availability.
- Only English metadata is registered.
- Provider choice is internal and fixed to the mock.
- Phase 6A.3 physical Android and iOS qualification remains blocked and
  mandatory before production release.

## Phase 13 production-readiness constraint

Phase 13 does not add or activate a provider. Production configuration rejects
both AI flags, and mobile release configuration rejects mock/preview behavior.
Operational readiness checks PostgreSQL, migration compatibility, and Redis
only. No provider health probe, endpoint, SDK, key, secret, model, prompt,
outbound network path, fallback, or persistence is introduced.

## Phase 14 release-gate constraint

The release manifest records only the two production execution booleans and
content-free evidence IDs. `ReleaseGateEvaluator` independently blocks a
candidate if production AI or mock execution is enabled. It neither registers
nor initializes a provider. The closed default registry remains exactly
`mock-ai-provider.v1`, and production configuration prevents its execution.

## Phase 16 GPT-5.6 Terra integration

Phase 16 adds a separately consented development/staging provider identified as
`openai-responses-gpt-5.6-terra.v1`. It preserves the historical Phase 12 closed
registry and its deterministic mock tests; the live provider is selected only by
typed server configuration and cannot be selected by the client.

`OpenAITerraProvider` owns the OpenAI SDK boundary. It is fixed to the Responses
API and `gpt-5.6-terra`, parses directly into a strict Pydantic schema, requests
`store=False`, and supplies a keyed pseudonymous safety identifier. Credentials
and the safety-identifier secret are server-only. Route handlers do not import or
call the SDK.

Unlike Phase 8's content-free structural foundation, this path sends reviewed
message text only after separate `external_ai_processing` consent. The context
is explicitly allowlisted and bounded; it excludes screenshots, OCR and source
metadata, names, timestamps, account IDs, deleted content, structural events,
and arbitrary metadata. Output evidence references must resolve to the exact
events sent. Raw provider responses and validated coaching results are not
persisted.

Production still rejects enabled AI and the Phase 14 release evaluator still
blocks it. Phase 16 is an implemented development/staging integration, not a
claim of provider availability or release qualification. See
`phase-16-openai-terra-integration.md` for activation and remaining gates.

## Phase 18 Z.ai GLM-5.2 integration

`zai-chat-completions-glm-5.2.v1` is a second approved development/staging
adapter selected only by `AI_PROVIDER_MODE=zai_glm`. It uses the official
OpenAI-compatible base URL, fixes `model=glm-5.2`, enables thinking with high
reasoning effort, requests JSON object mode, and validates the resulting object
against `GLMCoachOutputV1`. JSON mode is not treated as schema enforcement;
Pydantic, evidence-reference checks, finish-reason checks, and token-accounting
checks remain mandatory after the provider returns.

`app.ai.external_safety` is intentionally provider-independent. It runs before
and after the GLM call and has no SDK dependency. This keeps provider capability
and ConvoCoach policy as separate defenses. The route handler continues to call
only `ConversationCoachPreviewService` and never imports an AI SDK.

## OpenRouter tiered integration

`openrouter-chat-completions-tiered.v1` is selected only by
`AI_PROVIDER_MODE=openrouter_tiered`. `ConversationCoachPreviewService` supplies
the allowance repository with a server-owned plan-to-model mapping. The
reservation returns the selected model, which is used for both the provider call
and exact model-price accounting. Welcome/Free currently maps to
`openai/gpt-4o-mini`; verified Plus maps to `openai/gpt-5.6-terra`.

`OpenRouterTieredProvider` requests a strict JSON Schema response and routing
with `data_collection=deny`, `zdr=true`, and `require_parameters=true`. It
retains the same bounded context, keyed pseudonym, independent pre/post safety,
evidence-reference, refusal, finish-state, and usage validation rules. The app
accepts a safe bounded OpenRouter model slug so a future server-side model swap
does not require a client release, but any swap still requires provider, safety,
schema, pricing, and regression qualification. See
`openrouter-tiered-ai-routing.md`.
