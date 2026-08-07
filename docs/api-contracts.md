# API Contracts

## Phase 14 authentication clarification

HTTP authentication remains `Authorization: Bearer <credential>`. The server
never accepts a client-supplied application user identifier. A verifier must
produce a bounded subject, exact issuer and audience set, and optional bounded
profile claims. Email is eligible for persistence only when the verifier marks
it verified. Missing, invalid, oversized, or unavailable verification produces
the existing generic `401` response and never returns a token, provider error,
claim value, key URL, or signature detail.

Phase 14 adds no route. Release-candidate manifests and gate reports are offline
operator contracts under `app.release`; they are not served by FastAPI and
cannot change runtime state.

All product endpoints use `/api/v1` and require a verified bearer token.
Foreign and missing resources both return 404. Validation failures use FastAPI's
structured 422 response. Raw bearer tokens and message bodies must never be
logged.

| Method | Path | Purpose |
| --- | --- | --- |
| `POST` | `/auth/session/verify` | Verify token and resolve server user |
| `GET` | `/users/me` | Read current user |
| `GET/PATCH` | `/users/me/preferences` | Read/update user preferences |
| `GET/PATCH` | `/communication-profile` | Read/update explicit profile choices |
| `POST/GET` | `/consents` | Append/list consent decisions |
| `POST/GET` | `/conversations` | Create/list owner-scoped conversations |
| `GET/DELETE` | `/conversations/{id}` | Read/delete one owned conversation |
| `POST` | `/conversations/{id}/messages` | Add one manual message |
| `POST` | `/conversations/{id}/confirm` | Persist a reviewed normalized import |
| `POST` | `/conversations/{id}/coach-preview` | Run the default-off deterministic mock preview |
| `GET` | `/subscription/status` | Read the authenticated server-owned plan and AI allowance snapshot |
| `POST` | `/privacy/delete-account` | Remove private data and queue provider cleanup |

Conversation list items include import type, confirmation status, and readiness,
but deliberately omit message bodies. Detail responses include normalized message
speaker, timestamp quality, OCR confidence, source screenshot index, status, and
content-free extraction provenance for screenshot imports.

`POST /conversations/{id}/confirm` requires active
`save_conversation_history` consent and a readiness score from 85 through 100.
It accepts 2-2000 reviewed messages and 1-10 source metadata records. Screenshot
sources must be marked `deleted`; paste sources must be `not_stored`. Screenshot
imports require bounded provider, provider-version, extraction-version,
preprocessing-version, and confidence-availability fields. Paste imports reject
OCR provenance. Screenshot bytes, paths, URLs, source hashes, and analysis fields
are not part of the contract. A visible time with no visible date may be retained
as bounded `visible_timestamp_text` while the parsed timestamp stays null;
estimated timestamps are rejected.

`POST /conversations/{id}/coach-preview` accepts no request body. It requires a
verified owner, active `save_conversation_history` consent, a confirmed
conversation, and a persisted, contiguous, fully reviewed
`conversation-events.v1` timeline. `AI_COACHING_ENABLED` and
`AI_MOCK_EXECUTION_ENABLED` must both be true; both default false.

Success uses exact `conversation-coach-preview.v1` keys containing only schema
and calculation versions, ordered renderer localization keys/statuses,
structural reference counts, opaque response/correlation IDs, explicit notices,
and deterministic-mock provenance. Failures use
`conversation-coach-preview-error.v1` with closed error code, localization,
retry, and correlation fields. Both success and failure are non-cacheable. No
prompt, provider/model selection, conversation payload, raw analytics, evidence
payload, provider response, generated content, participant name, screenshot,
OCR, deleted content, internal diagnostic, or exception belongs to this API.

In development/staging, server configuration may instead select
`openai_terra`, `zai_glm`, or `openrouter_tiered`. The same bodyless endpoint
then additionally requires active `external_ai_processing` consent using policy
`external-ai-processing-v3`. Missing consent returns the stable
`external_processing_consent_required` error and does not call the provider.

External execution requires a canonical UUID `Idempotency-Key`. A new key reserves
one server-owned allowance before the provider is called. The same key cannot
be used for a different reviewed event sequence, and an in-progress or completed
key cannot trigger a duplicate billable call. Allowance exhaustion, rate
limits, and cost ceilings return stable non-cacheable `429` errors.

External success uses exact `conversation-coach.v2` plus the approved
Terra, Z.ai GLM-5.2, or `openrouter-coach-output.v1` provenance contract. The
OpenRouter contract fixes the provider identifier while allowing a bounded
deployment-selected `provider/model` slug. It contains summary, observations with
uncertainty/alternative interpretations/opaque evidence event IDs, next steps,
up to three user-reviewable reply drafts, safety notices, limitations, exact
approved provenance, content-free token totals, and correlation/response IDs. It
does not contain the request context, participant names, screenshots, OCR,
source metadata, prompts, raw provider response, application user ID,
credentials, or secrets. It adds an allowance snapshot containing only plan,
allowance kind, window, limit, consumed, reserved, remaining, and purchase
availability. The server does not persist the output and sends `Cache-Control:
no-store`.

The existing `POST /api/v1/consents` contract records the external-processing
decision. Provider and model selection remain server-owned and are never request
parameters. Under `openrouter_tiered`, the atomic allowance reservation resolves
welcome/Free users to the configured free model and verified Plus users to the
configured paid model; client plan claims are ignored.

`GET /subscription/status` returns `subscription-status.v1`. Apple/Google plan
claims from the client are never accepted. A Plus plan is effective only from a
current server-verified entitlement. Store purchase remains unavailable until
receipt verification and webhook handling are deployed.

## Operational contracts

`GET /health/live` returns process status, service name, and version only. It
does not probe a dependency. `GET /health/ready` returns the overall
`ready`/`not_ready` state plus configuration, lifecycle, database, migration,
and Redis status. Local/test dependency states may be `not_checked`; production
readiness requires checked `ready`/`compatible` states.

Every response carries `X-Correlation-ID`. A supplied identifier is accepted
only when it is a canonical UUID. Unexpected errors and oversized requests use
content-safe envelopes containing a stable code and that UUID only. Production
does not expose `/docs` or `/openapi.json`.
