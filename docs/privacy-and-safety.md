# Privacy and Safety Baseline

Conversation content can expose identity, location, relationships, sexuality,
health, and other sensitive information. ConvoCoach treats all imported or typed
conversation content as sensitive, regardless of whether a platform labels it as
personal data.

## Data lifecycle

Before a feature handles conversation content, its design must state:

- what data enters the system and through which user action;
- whether processing occurs on-device, on ConvoCoach infrastructure, or through a
  named processor;
- the minimum retained representation and retention period;
- who can access it and how access is audited;
- how users export and delete it;
- what is excluded from logs, analytics, training, and support tooling.

Raw content should be processed ephemerally unless the user explicitly chooses a
feature that requires storage. Derived data can remain sensitive and must not be
treated as anonymous merely because names were removed.

## Phase 4 through Phase 7 controls

- Authenticated identities are derived from a verified bearer token, never a
  client-supplied user ID.
- Every conversation lookup includes the authenticated owner ID. A foreign
  resource returns the same 404 response as a missing resource.
- Consent decisions are append-only records containing type, grant/withdrawal,
  policy version, and timestamp.
- Conversation-list responses include counts and labels but no message bodies.
- Deleting a conversation immediately removes its participants, messages,
  events, and event relationships.
- Requesting account deletion removes conversations, consents, preferences, and
  the communication profile; redacts email/display name; blocks re-entry; and
  records pending identity-provider cleanup.
- The provider subject remains temporarily on the soft-deleted user solely to
  prevent accidental account recreation and support provider cleanup. Final
  identifier erasure belongs to the hardened deletion worker in Phase 10.
- Screenshot selection is user-initiated. Bytes remain in a bounded in-memory
  mobile store, are never included in the backend confirmation payload, and are
  cleared when import is abandoned or normalized content is saved.
- Preprocessing occurs in a mobile isolate. EXIF, text chunks, and ICC metadata
  are removed before a sanitized PNG reaches the on-device recognizer.
- The recognizer's randomized system-temporary directory is deleted after each
  attempt. Processing cancellation retains original bytes only for explicit
  retry; abandoning the import clears them.
- Session idempotency uses screenshot digests in memory only. Digests, raw OCR
  text, screenshot content, and paths are not logged or persisted.
- Pasted text and on-device extracted text remain editable before storage.
  Automatic screenshot preparation does not invoke coaching: nothing is analyzed
  until the user confirms the reviewed normalized sequence. The **Confirm and
  analyze** action saves that confirmed sequence before entering the separately
  disclosed external-processing consent flow.
- Backend source rows retain only MIME type, byte size, order, and a mandatory
  `deleted` or `not_stored` status. There is no path, object key, URL, or blob.
- Readiness is labeled and implemented as data quality only.
- Phase 6A ground truth and screenshots contain original synthetic conversation
  content only. Generated images are temporary, and benchmark exports contain no
  transcript, screenshot, source path, or source hash.
- Content-free extraction diagnostics are limited to counts, confidence
  availability, provider versions, and source ordering. They cannot reconstruct
  a conversation.
- Phase 6A.2 readiness evidence omits device IDs and user-assigned device names.
  Benchmark v2 and comparison exports pass exact-field validation and contain
  only hardware class/version facts, synthetic fixture IDs, safe outcome
  categories, and aggregate measurements.
- Phase 6A.3 reran only the original synthetic, content-free qualification
  workflow. No physical device was available, no native OCR content was
  produced, and no screenshot, transcript, prompt, device identifier, source
  path, or source hash was uploaded or added to a report. A clean release bundle
  passed both benchmark-path and synthetic-corpus artifact scans.

The Phase 6A.1 typed event runtime preserves the same privacy boundary. Media
bytes remain temporary, voice notes are not transcribed without explicit
consent, contact and payment metadata is minimized or rejected, unknown content
is not guessed, and screenshot bytes or paths never reach the backend. Event
replacement is owner scoped and consent gated; conversation/account deletion
cascades through both event tables. The authenticated `account-export.v1`
surface includes reviewed events and relationships in an owner-scoped JSON file
while excluding raw screenshot bytes and paths, identity-provider subjects,
transaction hashes, internal request identifiers, and AI prompts. The mobile
client warns that the export contains private data, uses the system share sheet,
and deletes its temporary file after that sheet returns.

Phase 6B derives deterministic analytics in memory from accepted canonical
events only. It creates no database table, migration, API route, cache, history,
or customer UI. Results and evidence are immutable domain values; evidence
contains event UUIDs, relationship UUIDs, and a calculation version only. It
contains no message text, captions, OCR, screenshot data, paths, hashes,
participant names, prompts, deleted content, or device identifiers. The engine
does not log. Reaction type is an in-memory derived metric value and must not be
logged or persisted by this phase. Missing information is exposed through
stable quality codes rather than guessed.

Phase 7 renders only an immutable, supplied mobile projection of those values.
It adds no analytics API, persistence, cache, history, export, screenshot, or
report. The default repository returns no result rather than inventing preview
metrics. UI evidence details contain only event UUIDs, relationship UUIDs, and
version strings; the dashboard does not log values or evidence. Unsupported
metrics and missing-data reasons stay visible. Customer copy explicitly rejects
interest, compatibility, and relationship-quality interpretations.

Phase 8 adds a disabled backend architecture boundary only. Its provider-neutral
evidence projection contains structural accepted-event facts, deterministic
metric values, quality metadata, and event/relationship UUIDs. It excludes
message text, screenshots, OCR, bytes, paths, hashes, source metadata, device
logs, participant names, prompts, raw provider payloads, deleted or hidden
events, edit/deletion markers, unknown events, pending-review events, and valid
duplicate sources. No Phase 8 module logs, persists, transmits, or exposes this
evidence through an API. The only provider is a deterministic local mock.
Failures contain stable codes rather than exception or payload content, and the
runtime feature flag defaults off.

Phase 9 defines structured coaching-response shapes without generating
coaching. Response serialization may contain only response/request/evidence
UUIDs, closed capability and status identifiers, analytics metric identifiers
and versions, allowlisted localization keys, evidence-sufficiency descriptors,
safety codes, and local provenance identifiers. Exact-key parsing rejects
message text, screenshots, image bytes, OCR, prompts, raw evidence, deleted
content, and participant names before typed construction. Validation restricts
every structural reference to the exact minimized Phase 8 evidence package.
Failures never echo JSON payloads, and no Phase 9 component logs, persists, or
transmits a response.

Phase 10 lifecycle requests and diagnostics remain content-free even though the
coordinator consumes reviewed canonical input internally. Execution contracts
contain request/configuration identifiers only; source input is supplied
separately. Context contains derived UUIDs, and diagnostics contain only sequence,
stage, and status. Provider exceptions, cancellation, timeout, raw placeholder
JSON, evidence packages, structured-response JSON, message text, screenshots,
OCR, prompts, participant names, and deleted content are never logged or
returned. The coordinator has no API, persistence, transport, background task,
or external processor.

Phase 11 exposes only the validated content-free renderer projection through an
authenticated owner-bound endpoint. It requires active history consent and a
confirmed persisted event timeline, rejects all request bodies, adds no
logging, and sets no-store response headers. The transport contains version
facts, allowlisted localization keys, structural counts, opaque identifiers,
closed errors, and deterministic-mock provenance. It excludes conversation
text, names, screenshots, OCR, prompts, evidence payloads, raw analytics,
provider payloads, deleted/hidden/rejected content, diagnostics, exceptions,
paths, device data, credentials, and secrets. No preview output is persisted.

Phase 12 provider metadata, selection, configuration, health, and factory
contracts remain content-free and internal. They contain identifiers, versions,
closed capabilities, language metadata, lifecycle, visibility,
mock/production classification, and existing boolean feature flags only. They
cannot carry endpoints, keys, tokens, certificates, OAuth data, prompts,
conversation content, screenshots, OCR, evidence, analytics payloads,
participant names, raw responses, or exceptions. No provider metadata is
exposed through the Phase 11 transport. The registry performs no persistence,
and structural health performs no external probe.

## Product safety

Coaching should help users communicate honestly and respect boundaries. The
product must not optimize for persistence after rejection, conceal identity,
manufacture emotional dependency, or automate pressure. Generated content must
remain a draft and should be framed as one possible response, not the correct
interpretation of another person.

Live generated responses expose an in-app safety-reporting action. A report sends
only the authenticated owner, owned conversation identifier, opaque response
identifier, and one bounded category. It cannot carry message text, screenshots,
prompts, generated output, participant names, or free-form notes. Reports are
included in the owner's export and cascade with conversation or account deletion.
This content-free ledger supports moderation triage without creating a second
store of intimate conversation content.

Features involving crisis, abuse, self-harm, threats, stalking, minors, or sexual
coercion require dedicated policy and escalation design before implementation.
The current implementation contains on-device OCR, typed event review,
data-quality readiness, deterministic structural/count/timing analytics, and a
read-only conversation-data dashboard for supplied analytics. It contains no
semantic AI, inference about people or relationships, screenshot upload,
analytics transport or persistence, scoring, or generated coaching.
It also contains the disabled Phase 8 provider-neutral foundation and mock
placeholder path. It still contains no external AI processor, prompt content,
model call, advice, interpretation, or generated message.

## Phase 13 operational privacy

Request correlation uses opaque UUIDs and never derives identifiers from the
user, owner, conversation, or URL. Operational JSON logs allow only timestamp,
level, closed event, correlation UUID, HTTP method, route template, status,
duration, and lifecycle. Log messages, arguments, exceptions, headers, tokens,
queries, bodies, prompts, screenshots, OCR, participant data, and response
payloads are ignored.

Safe unexpected-error and request-size envelopes contain only a stable code and
correlation UUID. Responses are non-cacheable and receive deny-by-default
browser/privacy headers. Production OpenAPI is disabled. Mobile release
configuration rejects embedded API access tokens.

Readiness checks contain only dependency status and exact migration
compatibility. They never send conversation data, invoke AI, write a database
record, apply a migration, or log a connection URL.

## Phase 14 identity and release-evidence privacy

Authentication claims are bounded before current-user resolution. Bearer
credentials, issuer responses, signing keys, claim payloads, emails, subjects,
display names, and provider errors are excluded from operational logs and
release evidence. An email may be stored only when the injected verifier marks
it verified. The production verifier validates asymmetric OIDC/JWKS credentials,
exact issuer and audience, required timestamps, and bounded token lifetime. It
retains only the minimal subject and explicitly verified optional profile
claims; raw tokens, JWKS responses, signing material, and provider errors remain
excluded from logs.

Mobile authentication contracts expose sanitized lifecycle and an optional
server-opaque account reference only. The OIDC adapter uses Authorization Code
with PKCE, stores access/refresh credentials only in platform secure storage,
does not retain the ID token, and clears the session after an unrecoverable
refresh failure. Release mode disables preview authentication and rejects any
compiled bearer token.

The global Stats journal is device-local and user-initiated. It stores an opaque
conversation reference, bounded reply/plan choices, three 1–5 self-ratings, an
update timestamp, and an optional 1,000-character private reflection in platform
secure storage. It reads no contacts, notifications, inboxes, calendars, or
provider accounts and sends no journal value to the backend or AI processor.
Deleting a conversation removes its outcome from the next aggregate; `Clear
private stats` deletes the entire journal while preserving saved conversations.
The communication score is a self-assessment and never represents another
person's interest, compatibility, intent, or likely date outcome.

Signing out clears the protected Stats journal before ending the local session.
Account deletion first requires a successful authenticated server deletion
request; only then does the app clear the local journal and session. A failed
server request leaves both intact and reports a generic retryable failure, so a
UI success can never hide an undeleted account.

Supply-chain and artifact evidence contains logical IDs, SHA-256 digests, byte
sizes, closed status/failure codes, source revision, and signing/provenance
booleans. It excludes host paths, file contents, signing material, logs,
screenshots, messages, OCR, prompts, participant data, user identifiers,
credentials, and private metadata. Invalid manifests produce a content-free
failure rather than echoing input.

Phase 14 adds no data collection, persistence, schema, migration, external
processor, identity network request, AI request, deployment, or store
submission.

## Phase 16 external AI processing

GPT-5.6 Terra is an optional external processor in development and staging. It
is disabled by default and requires consent separate from conversation-history
storage. The mobile disclosure explains that only the reviewed text, speaker
roles, and opaque event identifiers are sent; screenshots, names, source paths,
OCR metadata, and the application account identifier are not sent. Revoking or
not granting the external-processing consent prevents the request.

The server selects only confirmed, non-deleted text and emoji-message events and
bounds the context before the provider boundary. A keyed HMAC value is used as
the OpenAI safety identifier, so the raw owner UUID is not disclosed. The
adapter requests `store=False`; ConvoCoach does not persist the request, raw
provider response, or validated coaching result. Transport responses are
non-cacheable. Content-free token totals may be observed for budget controls.

Structured output remains untrusted until strict schema and evidence-reference
validation succeed. The prompt frames interpretations as uncertain and
contestable, requires alternatives, preserves user review of every draft, and
prohibits manipulation, harassment, boundary evasion, diagnoses, ranking,
guaranteed outcomes, and romantic or sexual interactions involving minors.

No API credential or safety-identifier secret belongs in mobile code, logs,
tests, committed environment files, or response payloads. Production activation
remains prohibited until processor disclosure, retention/deletion review,
authentication, monitoring, incident response, safety evaluation, and physical
device qualification are complete.

## Phase 17 usage and entitlement privacy

AI allowance enforcement stores no conversation body, prompt, provider response,
screenshot, participant name, or source location. Its ledger contains opaque
owner/conversation references, an idempotency key, a structural fingerprint,
plan/window counters, model identifier, content-free token totals, estimated
cost, timestamps, and a correlation ID. Budget-threshold logs emit the threshold
kind and aggregate percentage only; they omit the owner and private content.

The mobile conversation client sends only user-confirmed normalized messages,
typed events, bounded source-disposal metadata, and consent actions. Raw
screenshot bytes remain on-device and temporary. Coaching results remain
non-persistent; viewing previous generated results later would require a
separate encrypted-retention design and explicit consent.

## Phase 18 Z.ai processing and independent safety

When server configuration selects `zai_glm`, Z.ai is the external processor for
GLM-5.2. Consent policy `external-ai-processing-v2` discloses this processor and
supersedes the Terra-only version. Only confirmed reviewed message text, speaker
roles, and opaque event IDs cross the boundary. Screenshot bytes, names, source
and OCR metadata, the raw account UUID, credentials, and deleted or structural
events are excluded. The application sends a keyed pseudonym as `user_id` and
does not persist the generated result. Z.ai processing remains subject to its
own terms and retention policy; ConvoCoach does not claim a provider-side
`store=false` guarantee for this API.

Safety does not depend on the model alone. A deterministic local gate blocks
detected under-18 romantic or sexual contexts before transmission. Other narrow
boundary, coercion, stalking, deception, and harassment signals are sent only as
content-free labels and require a response with safety guidance and no reply
drafts. The backend rejects malformed JSON, unknown evidence references,
unsafe drafts, missing safety redirects, provider-sensitive termination, and
inconsistent token usage with stable content-free errors.

## OpenRouter tiered processing

When server configuration selects `openrouter_tiered`, consent policy
`external-ai-processing-v3` discloses OpenRouter and the underlying model
provider. The server selects `openai/gpt-4o-mini` for welcome/Free users and
`openai/gpt-5.6-terra` for verified Plus users. The client cannot choose a plan,
provider, or model, and the OpenRouter key never enters the mobile application.

The data minimization and independent safety rules above remain unchanged.
Requests additionally ask OpenRouter for zero-data-retention routing, deny
provider data collection, and require support for the structured-output
parameters. These are routing constraints, not a promise that substitutes for
processor-contract review. Launch remains blocked until OpenRouter and every
eligible underlying provider have approved terms, locations, subprocessors,
training controls, and retention/deletion behavior documented in the final
privacy notice and data inventory.

The usage ledger stores the exact backend-selected model on the reservation and
uses that model's configured price on completion. It still contains no message
body, prompt, provider response, screenshot, name, or raw account identifier.
See `openrouter-tiered-ai-routing.md` for the complete boundary.

## Phase 19 mobile privacy hardening

The Flutter root covers private UI whenever the application is not resumed so
operating-system app-switcher snapshots do not expose a conversation screen.
Android release configuration disables cloud backup, device-to-device transfer,
and cleartext traffic; only the debug manifest retains the explicit local HTTP
development override. iOS Debug and Profile builds declare local-network access
only for the user-approved Mac development server; Release keeps that exception
absent. iOS declares no tracking, lists the linked account and
user-content categories used only for app functionality, and requests complete
file protection for debug/profile and release data.

These controls do not authorize retention or external processing. Screenshot
bytes remain temporary and on-device, generated coaching remains non-persistent,
and production external-AI activation still requires separately evidenced
processor and independent safety approvals.
# Production launch documents

The user-facing launch policy remains a counsel-review draft at
`docs/Privacy-Policy-Draft.md`; related service terms and the independent AI safety
protocol live alongside it. Placeholders or developer-only approval cannot pass the
production legal/privacy or independent-safety gates.
