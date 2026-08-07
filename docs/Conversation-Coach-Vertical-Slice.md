# Conversation Coach Vertical Slice

## Status and scope

Phase 11 supplies one secure, non-production integration slice from an
authenticated, owner-owned, consented, reviewed `conversation-events.v1`
timeline to the existing deterministic Phase 10 mock pipeline and then to an
accessible Flutter preview. Both server execution flags and the mobile entry
flag default off.

This is infrastructure validation only. It generates and renders no coaching,
advice, recommendations, message drafts, interpretations, summaries, scores, or
claims about another person. The only reachable provider is
`mock-ai-provider.v1`; it has no external SDK or network implementation.

## Architectural flow

```text
Flutter owned-conversation detail
  → explicit local/build gate
  → POST owner-bound coach-preview endpoint (empty body)
  → authentication + owner lookup + active consent + confirmed-event checks
  → Phase 6B deterministic analytics
  → Phase 8 minimized evidence + safety validation
  → Phase 10 execution coordinator
  → deterministic local mock provider
  → Phase 9 strict response validation + renderer projection
  → exact-key content-free API transport
  → strict immutable Flutter transport
  → Riverpod state controller
  → placeholder-only accessible preview
```

The endpoint does not accept a prompt, provider, model, event payload,
analytics, evidence, or response from the client. It loads only the stored
owner-bound canonical event sequence. Compatibility-projected legacy messages
and draft conversations are rejected.

## API

`POST /api/v1/conversations/{conversation_id}/coach-preview`

- requires a verified bearer identity;
- returns 404 for both a foreign and missing conversation;
- requires active `save_conversation_history` consent;
- requires a confirmed conversation with a persisted, contiguous, reviewed
  event sequence;
- accepts no request body;
- returns `Cache-Control: no-store, max-age=0`, `Pragma: no-cache`, and
  `X-Content-Type-Options: nosniff`;
- does not commit, persist, cache, queue, or retain its result.

The success contract is `conversation-coach-preview.v1`. It contains response,
renderer, analytics, calculation, and source-event versions; ordered renderer
sections; allowlisted localization keys; structural evidence counts; an opaque
correlation identifier; and explicit deterministic-mock provenance.

The failure contract is `conversation-coach-preview-error.v1`. It contains a
stable error ID, closed machine code, localization key, retryability,
content-free retry guidance, and correlation ID. Authentication, ownership,
consent, review, schema, timeline, safety, cancellation, timeout, provider,
response-validation, unsupported-capability, disabled, and internal-safe
failures remain distinguishable.

## Feature flags

Backend:

- `AI_COACHING_ENABLED=false`
- `AI_MOCK_EXECUTION_ENABLED=false`

Both must be explicitly enabled. The first disabled check prevents analytics,
evidence construction, request construction, or mock invocation. The second
prevents provider invocation even when the broader execution flag is enabled.
There is no production auto-enable or remote configuration.

Flutter:

- `CONVOCOACH_COACH_PREVIEW_ENABLED=false`
- `CONVOCOACH_API_BASE_URL` has no default
- `CONVOCOACH_API_ACCESS_TOKEN` has no default

The owned-conversation entry remains unavailable unless all three are supplied
at build time. No token or backend address is committed to source.

## Mobile contracts and states

The Flutter decoder requires exact keys, exact schema versions, the fixed
section order, closed status/error vocabularies, UUID-shaped identifiers,
mock-only provenance, and allowlisted localization keys. Unknown fields,
generated text keys, unsupported versions, invalid order, and inconsistent
retry metadata fail closed.

The Riverpod controller exposes immutable states for unavailable, feature
disabled, mock disabled, loading, ready placeholder, empty, review incomplete,
unsupported conversation/version, consent required, timeout, cancellation,
execution failure, network unavailable, and generic safe failure. Cancellation
aborts the in-flight HTTP request. A bounded client timeout moves to its own
state.

The preview renders only infrastructure availability, unavailable capability
labels, explanation placeholders, safety notices, structural reference counts,
schema versions, and explicit mock status. Content-free response/correlation
identifiers are visible only under Flutter debug mode.

## Privacy and security

The transport and UI never expose conversation text, participant names,
screenshots, OCR output, image bytes, prompt material, evidence payloads, raw
analytics, provider responses, deleted/hidden/rejected content, stack traces,
exceptions, filesystem paths, device data, credentials, or secrets. The Phase
11 code adds no logging.

The route never trusts a client-supplied user, event sequence, provider, model,
prompt, analytics result, or response. Authorization is fail-closed and foreign
resources are indistinguishable from missing ones. Existing account-deletion
and consent enforcement execute before the AI pipeline.

## Accessibility

The preview uses semantic headings, live-region state surfaces, descriptive
mock/safety labels, textual status with icons, logical focus order, scalable
text, shared high-contrast semantic colors, and existing minimum 44-by-44 touch
targets. It inherits the application reduced-motion scope and adds no new
decorative animation.

## Performance

Execution is synchronous within the request, deterministic, and in memory.
Analytics runs once. The existing evidence, request, provider, parser,
validator, and projection instances each run once. There is no worker, queue,
retry loop, speculative execution, precomputation, response history, or cache.
The mobile response is bounded to 256 KiB.

## Limitations and deferred work

- This preview is not a production coaching feature.
- There is no real authentication flow in the current Flutter foundation; an
  explicit build token is required for local integration only.
- No external model/provider has been selected or approved.
- No content-bearing evidence or genuine coaching contract exists.
- No preview result is stored or recoverable.
- Phase 6A.3 remains `BLOCKED` until physical Android and iOS qualification
  passes on supported devices. Simulator and host checks do not satisfy it.
