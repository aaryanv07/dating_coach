# OpenRouter Tiered AI Routing

## Status and scope

The backend can select `AI_PROVIDER_MODE=openrouter_tiered` for the existing
reviewed-conversation coaching action. The server routes welcome and Free users
to `openai/gpt-4o-mini` and verified Plus users to
`openai/gpt-5.6-terra`. The mobile client cannot select a model, submit a plan
claim, or access the OpenRouter key.

This is an implementation and test record, not production authorization.
External-processor review, independent safety qualification, deployed billing
and identity, signed physical-device qualification, and all release-manifest
gates remain mandatory.

## Request boundary

A model request is allowed only after the user has:

1. imported and corrected a conversation;
2. explicitly confirmed the normalized event sequence;
3. consented to store that reviewed history; and
4. separately accepted `external-ai-processing-v3`.

Only bounded reviewed message text, speaker labels, opaque event IDs, a locale,
and content-free safety flags cross the adapter boundary. Screenshot bytes,
paths, names, timestamps, OCR metadata, the raw account UUID, subscription data,
credentials, and structural or deleted events are excluded. A keyed HMAC
pseudonym is supplied for abuse controls.

Every request asks OpenRouter to deny provider data collection, require a
provider that supports the requested structured parameters, and use
zero-data-retention routing. These routing requests reduce exposure but do not
replace legal review of OpenRouter and the selected underlying provider. The app
discloses both layers before consent.

## Validation and safety

The adapter requests strict JSON Schema output and still treats the result as
untrusted. It validates the response with a strict Pydantic contract, permits
only evidence IDs from the submitted context, verifies token accounting, and
runs the provider-independent pre- and post-generation safety gates. A refusal,
content-filter termination, malformed result, unknown evidence reference, or
unsafe draft returns a stable processing error. Raw prompts, provider responses,
and generated coaching are not logged or persisted.

## Server-owned model configuration

The model mapping is deployment configuration:

```dotenv
AI_PROVIDER_MODE=openrouter_tiered
OPENROUTER_BASE_URL=https://openrouter.ai/api/v1
OPENROUTER_FREE_MODEL=openai/gpt-4o-mini
OPENROUTER_PAID_MODEL=openai/gpt-5.6-terra
OPENROUTER_FREE_REASONING_EFFORT=none
OPENROUTER_PAID_REASONING_EFFORT=medium
```

Changing to another OpenRouter model requires changing the relevant model slug
and that model's input/output price configuration on the backend. The mobile
transport accepts a bounded `provider/model` slug and presents an unbranded
OpenRouter label for an unknown future slug, so a safe model swap does not
require shipping a new app. It does require schema compatibility, regression
tests, safety evaluation, pricing review, and a new deployment.

## Credentials

The API key and pseudonym secret are backend-only. Local development reads these
macOS Keychain services:

- `convocoach.openrouter.api-key`
- `convocoach.openrouter.user-secret`

Production uses separate Secret Manager values. Never place either value in a
Flutter define, source file, `.env` file, log, test fixture, crash report, or
release evidence.

## Usage and cost accounting

The allowance reservation resolves the effective server plan and selected model
inside the same locked operation. Completion charges the price table for the
model stored on that reservation, preventing a retry, plan change, or later
configuration change from applying the wrong price.

The defaults were verified against OpenRouter's model API on 2026-08-06:

| Model | Input, USD / 1M tokens | Output, USD / 1M tokens |
| --- | ---: | ---: |
| `openai/gpt-4o-mini` | 0.15 | 0.60 |
| `openai/gpt-5.6-terra` | 1.00 | 6.00 |

Pricing is mutable external data. Recheck the model pages and update the
micro-USD environment values before every production deployment or model swap.
Allowance limits, per-user ceilings, and the global budget continue to fail
closed independently of the provider balance.

## Verification

Deterministic backend tests cover request minimization, strict-schema
normalization, reasoning-model parameter compatibility, structured-output and
privacy-routing parameters, minor blocking before the network, evidence
validation, plan-to-model selection, model-specific cost accounting, retries,
and pseudonym stability. Flutter tests cover both tier labels, a safe future
model slug, malformed/mismatched provenance, consent disclosure, large text,
and result presentation. A live synthetic smoke request is separate evidence
and must never contain a real conversation.

On 2026-08-06, one explicitly approved synthetic request per tier passed. The
content-free result was:

| Tier | Model | Total tokens | Estimated model cost |
| --- | --- | ---: | ---: |
| Free | `openai/gpt-4o-mini` | 1,106 | USD 0.000316 |
| Plus | `openai/gpt-5.6-terra` | 1,142 | USD 0.003027 |

Both returned `openrouter-coach-output.v1` and passed local schema, evidence,
usage, and safety validation. The combined estimate was USD 0.003343. This is a
provider-connectivity smoke result, not a quality/safety evaluation or
production authorization. Request and response content was not printed or
stored.

After the live-discovered schema and reasoning-parameter fixes, Ruff formatting
and lint, strict MyPy across 111 backend source/test files, all 236 backend tests,
Flutter analysis, and all 171 Flutter tests passed.

Official references:

- [OpenRouter GPT-4o mini](https://openrouter.ai/openai/gpt-4o-mini)
- [OpenRouter model API](https://openrouter.ai/api/v1/models)
- [Structured outputs](https://openrouter.ai/docs/guides/features/structured-outputs)
- [Provider routing](https://openrouter.ai/docs/guides/routing/provider-selection)
- [Zero data retention](https://openrouter.ai/docs/guides/features/zdr)
- [Data-collection controls](https://openrouter.ai/docs/guides/privacy/data-collection)
