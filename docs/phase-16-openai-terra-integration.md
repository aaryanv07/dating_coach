# Phase 16: GPT-5.6 Terra Integration

## Status and release boundary

Phase 16 implements a real, backend-only GPT-5.6 Terra coaching path for
development and staging. It uses the OpenAI Responses API with a strict Pydantic
structured-output schema. The path is disabled by default, has no credential in
source control, and has not made a live billable model request.

This change does not authorize production release. Existing production
configuration and Phase 14 release gates continue to reject enabled AI. A later
release-qualification change must explicitly re-evaluate authentication,
physical-device evidence, privacy, budget, provider availability, and signing.

The implementation follows the official OpenAI documentation for
[GPT-5.6 Terra](https://developers.openai.com/api/docs/models/gpt-5.6-terra),
the [latest-model guide](https://developers.openai.com/api/docs/guides/latest-model),
[Structured Outputs](https://developers.openai.com/api/docs/guides/structured-outputs),
and [safety best practices](https://developers.openai.com/api/docs/guides/safety-best-practices).

## Implemented request path

1. FastAPI authenticates the caller and resolves the owner-scoped conversation.
2. The service requires active `save_conversation_history` consent.
3. Terra mode also requires separate active `external_ai_processing` consent
   under policy `external-ai-processing-v2`. Version 2 supersedes version 1 to
   disclose every currently approved external processor, including Z.ai.
4. Only explicitly reviewed, confirmed text and emoji-message events enter the
   provider context. Deleted, unknown, structural, and non-message events are
   excluded.
5. The newest context is bounded to 120 messages, 30,000 characters total, and
   1,200 characters per message. Screenshots, names, timestamps, source paths,
   source regions, OCR metadata, account IDs, and arbitrary metadata are absent.
6. The adapter calls exactly `gpt-5.6-terra`, requests the
   `terra-coach-output.v1` Pydantic schema, sets `store=False`, uses medium
   reasoning, and supplies an HMAC-derived safety identifier instead of the raw
   application user ID.
7. The backend rejects output that is refused, malformed, or cites an event ID
   outside the minimized input. Provider failures become stable, content-free
   errors.
8. The mobile client accepts only the exact versioned response, displays
   uncertainty and alternative interpretations, and labels reply suggestions as
   drafts the user must review. It never sends a draft automatically.
9. Neither raw provider payloads nor the validated coaching result are persisted.
   Responses are non-cacheable; only content-free token counts are returned for
   cost measurement.

Provider selection is server-owned through `AI_PROVIDER_MODE`. The client cannot
choose a provider or model, and no OpenAI credential is compiled into Flutter.

## Local or staging configuration

Provide secrets through the process environment or a secret manager, never a
tracked file:

```dotenv
AI_COACHING_ENABLED=true
AI_MOCK_EXECUTION_ENABLED=false
AI_PROVIDER_MODE=openai_terra
OPENAI_MODEL=gpt-5.6-terra
OPENAI_REQUEST_TIMEOUT_SECONDS=30
OPENAI_API_KEY=<secret>
OPENAI_SAFETY_IDENTIFIER_SECRET=<random-secret-of-at-least-32-characters>
```

The mobile debug build must separately enable the existing Conversation Coach
HTTP surface and point it at the intended non-production API. Never put
`OPENAI_API_KEY` or the safety-identifier secret in a Dart define, mobile
configuration, source code, log, screenshot, test fixture, or committed `.env`.

## Cost boundary

The official GPT-5.6 Terra model page listed, on 2026-07-26, USD 2.50 per million
input tokens, USD 0.25 per million cached input tokens, and USD 15.00 per million
output tokens. Prices can change. The subscription assumptions must be replaced
with measured token distributions and current prices before a paid launch.

The automated suite uses an injected fake transport. It verifies the exact
model request, minimization, consent, schema validation, error behavior, and
mobile rendering without network access or provider cost.

## Remaining launch gates

- provision a restricted OpenAI API project and rotated server-side key;
- obtain explicit approval for one billable synthetic smoke request;
- run safety, refusal, ambiguity, multilingual, schema, and prompt-injection
  evaluations with original synthetic conversations;
- implement owner-scoped entitlement, quota reservation, idempotency, usage
  ledger, and cost-alert behavior before enabling paid quotas;
- complete production authentication, deployment, privacy/legal processor
  disclosure, deletion/retention review, and incident controls;
- qualify the enabled experience on physical Android and iOS devices; and
- create signed artifacts and pass a newly authorized release manifest that
  knows about the Terra provider.
