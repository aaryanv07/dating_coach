# AI Coaching Response Schema

## Status and purpose

`ai-coaching-response.v1` is the provider-independent structured output boundary
for future coaching features. It defines how a response can describe supported
and unavailable capabilities, structural evidence, explanation placeholders,
safety notices, confidence about evidence sufficiency, and provenance.

It does not define or generate advice. Phase 9 has no prompt execution, external
provider, customer-facing coaching, recommendation, reply, first message, score,
or interpretation.

## Top-level schema

`StructuredCoachingResponseV1` contains:

- `metadata`: response UUID, request UUID, and locale;
- `capabilities`: closed supported identifiers plus structured unavailable
  identifiers and reasons;
- `evidence_links`: structural references to one explicit evidence-package UUID;
- `explanations`: localization-key placeholders linked to evidence;
- `safety_notices`: closed notice code, severity, localization key, and optional
  evidence-link references;
- `provenance`: local generator identifier plus evidence and analytics versions;
  and
- `schema_version`: `ai-coaching-response.v1`.

Each nested section has its own `v1` schema. Every Python contract is frozen and
uses slots.

## Capability registry

Phase 9 supports only response infrastructure:

- `response_schema`
- `evidence_references`
- `explanation_placeholders`
- `safety_notices`

The schema can mark the following future capabilities unavailable without
simulating them:

- coaching guidance;
- recommendations;
- reply or first-message drafting;
- Communication DNA;
- relationship scoring; and
- compatibility scoring.

Unavailable reasons are closed: `not_implemented`, `insufficient_evidence`,
`unsupported_data`, or `safety_restricted`. A capability cannot be both
supported and unavailable.

## Evidence link

A link contains only:

- link UUID;
- evidence-package UUID;
- accepted event UUIDs;
- accepted relationship UUIDs;
- packaged analytics metric identifiers;
- analytics schema version; and
- analytics calculation version.

The validator checks every reference against the exact Phase 8 evidence package.
A UUID omitted from that minimized package is forbidden; this covers deleted,
rejected, pending, unknown, duplicate-source, and otherwise excluded events.
Links cannot embed message text, screenshots, OCR, source metadata, participant
names, prompt text, or raw evidence.

## Explanation and confidence

An explanation contains a closed capability, `placeholder` or `unavailable`
status, an allowlisted localization key, evidence-link UUIDs, and an
evidence-sufficiency descriptor. It has no prose field. Confidence values apply
only to evidence availability:

- `not_applicable`
- `evidence_complete`
- `evidence_reduced`
- `evidence_unavailable`

They never claim confidence about attraction, interest, compatibility, intent,
emotion, health, or another person's internal state.

## Strict codec and validation

The standard-library JSON codec performs one deterministic serialization and
uses exact keys at every level. It rejects invalid JSON, unknown shapes, unknown
enum values, invalid schema versions, and forbidden content-bearing field names.
Failures contain a stable code and, when safe, only the rejected field name;
they never echo the payload.

Typed validation returns immutable structured failures for:

- invalid section versions;
- duplicate identifiers or capability conflicts;
- evidence-package mismatch;
- missing evidence links;
- event, relationship, or metric references outside the package;
- analytics/provenance version mismatch;
- invalid localization keys; and
- a placeholder that attempts to represent a real capability.

## Version negotiation

`CoachingResponseVersionNegotiator` accepts a caller-preferred ordered version
tuple and returns the first locally supported version. It returns an explicit
unsupported result when there is no intersection. Phase 9 supports only
`ai-coaching-response.v1`.

## Deterministic mock

The local mock derives stable evidence-link and explanation UUIDs from the
explicit evidence-package UUID. It returns infrastructure capabilities, marks
all real coaching capabilities `not_implemented`, emits one explanation
placeholder, and emits `no_coaching_generated`. It contains no advice-like text
and invokes neither the Phase 8 provider protocol nor any network.

## Renderer projection

The renderer projection contains response UUID, locale, ordered section IDs,
heading localization keys, semantic-label localization keys, availability
status, item localization keys, and structural evidence counts. It exposes no
evidence payload or user content and creates no UI. Future UI code must validate
the response first and resolve localization and accessibility semantics in its
own presentation layer.
