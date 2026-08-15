# Phase 18: Z.ai GLM-5.2 Integration

Date: 2026-07-29

## Outcome and boundary

Phase 18 implements Z.ai-hosted GLM-5.2 as the cost-priority external coaching
provider for local development and staging. The adapter calls the official
OpenAI-compatible Chat Completions endpoint with the fixed `glm-5.2` model,
thinking enabled, high reasoning effort, and JSON object output. Provider and
model choice remain server-owned. No Z.ai key is compiled into Flutter or
checked into the repository.

This is not a production-launch authorization. The bounded synthetic live smoke
recorded below passed, but production still requires the broader independent
safety evaluation, processor/legal approval, deployed identity and HTTPS
infrastructure, alerting, storefront verification, signed artifacts, and passing
physical Android/iOS qualification.

Official references used for this implementation:

- [GLM-5.2 overview and OpenAI-compatible setup](https://docs.z.ai/guides/llm/glm-5.2)
- [Chat Completions request and response contract](https://docs.z.ai/api-reference/llm/chat-completion)
- [Z.ai model pricing](https://docs.z.ai/guides/overview/pricing)

## Request path

1. The existing bodyless Coach endpoint authenticates the owner and accepts no
   provider or model field from the client.
2. The service requires saved-history consent, a confirmed reviewed event
   timeline, and separate `external-ai-processing-v2` consent.
3. A canonical idempotency key reserves one server-owned conversation-analysis
   allowance before any external request. Rate and user/global budget guards
   remain fail closed.
4. Only confirmed, non-deleted text and emoji-message events are selected. The
   context is capped at 120 messages, 30,000 characters, and 1,200 characters
   per message. Screenshot bytes, source paths, OCR metadata, timestamps, names,
   account IDs, and arbitrary metadata are absent.
5. The application sends an HMAC-derived pseudonymous `user_id`, never the raw
   account UUID.
6. Z.ai JSON mode is treated only as a serialization aid. The backend parses the
   response through strict `GLMCoachOutputV1`, rejects extra or missing fields,
   verifies every evidence event ID, requires one normal `stop` completion, and
   validates non-negative consistent token usage.
7. The public `conversation-coach.v2` response includes the exact GLM schema,
   provider, and model provenance triple. Flutter rejects mixed triples.
8. ConvoCoach does not persist the generated result or raw provider response,
   and all responses remain non-cacheable.

## Independent safety layer

`app.ai.external_safety` is independent of Z.ai and runs around the model call.
It returns only content-free internal labels and never logs the reviewed text.

- A detected under-18 romantic or sexual scenario is blocked before any network
  call.
- Narrow boundary-evasion, coercion, stalking, deception, and harassment
  signals may reach the model only as risk labels. The output must contain
  safety guidance and no reply drafts.
- Obvious unsafe drafts, missing safety redirects, malformed JSON, unknown
  evidence, a `sensitive` finish reason, and incomplete generations fail closed.
- The model prompt separately requires consent, honesty, uncertainty, plausible
  alternative interpretations, and user-reviewable drafts only.

This deterministic layer is deliberately conservative and is not a complete
moderation system. Before controlled launch it must be extended and measured
with original adult English/Hinglish safety fixtures, false-positive analysis,
adversarial prompt-injection cases, and provider-independent human review.

## Configuration and secrets

Safe defaults remain disabled in `.env.example`. The SSD helper now configures
the following runtime without echoing secrets:

```dotenv
AI_COACHING_ENABLED=true
AI_MOCK_EXECUTION_ENABLED=false
AI_PROVIDER_MODE=zai_glm
AI_USAGE_ENFORCEMENT_ENABLED=true
ZAI_MODEL=glm-5.2
ZAI_REQUEST_TIMEOUT_SECONDS=30
ZAI_API_KEY=<macOS-Keychain-secret>
ZAI_USER_IDENTIFIER_SECRET=<generated-Keychain-secret>
```

Run `./scripts/configure_local_ai_secrets.zsh` and paste the Z.ai key only into
the hidden macOS prompt. `./scripts/run_local_backend.zsh` reads that dedicated
Keychain item into the server process. Do not place the key in Passwords notes,
a Dart define, shell history, a tracked `.env`, screenshots, tests, or chat.

## Cost boundary

On 2026-07-29, Z.ai's official pricing page lists GLM-5.2 at USD 1.40 per
million input tokens, USD 0.26 per million cached input tokens, and USD 4.40 per
million output tokens. Runtime defaults therefore use 1,400,000 and 4,400,000
micro-USD per million uncached input/output tokens. Cached input is not claimed
or discounted by the current accounting path. Prices can change and must be
reviewed before launch.

## Verification and live smoke

The deterministic backend suite uses injected clients and providers, so it
incurs no model cost. It covers request parameters, minimization, schema and
evidence validation, refusal/failure mapping, pre/post safety, v2 consent,
provider-specific usage pricing, public provenance, and non-persistence. Flutter
coverage accepts only approved exact provider triples and verifies disclosure
and accessibility.

The first operator-approved live synthetic smoke attempt on 2026-07-29
authenticated successfully but returned HTTP 429 with Z.ai business code
`1113`, which Z.ai documents as insufficient account balance. After the
operator funded the general API balance, one retry passed against
`zai-chat-completions-glm-5.2.v1`, model `glm-5.2`, and schema
`glm-coach-output.v1`. The strictly validated result contained one observation,
three next steps, three reviewable reply drafts, no safety notice, and three
limitations. Usage was 1,030 input tokens and 757 output tokens (1,787 total),
with an estimated uncached list-price cost of USD 0.004773. No synthetic input
or generated output was printed, logged, persisted, or committed. This closes
the bounded live adapter smoke gate; it is not a substitute for the remaining
provider-independent safety evaluation or production-launch requirements.

Closing automated verification on 2026-07-29 passed Ruff formatting/lint,
strict MyPy across 101 backend source files, all 196 backend tests with warnings
as errors, dependency checks, Dart formatting, Flutter analysis, all 144 Flutter
tests, shell syntax, Docker Compose configuration, and `git diff --check`. The
separate Phase 6A host reference benchmark completed all seven fixtures with
perfect content-quality metrics, but its p95 latency was 18,956 ms against the
2,500 ms gate and it is not a physical-device run. That benchmark therefore
remains truthfully blocked and is not attributed to the GLM integration.
