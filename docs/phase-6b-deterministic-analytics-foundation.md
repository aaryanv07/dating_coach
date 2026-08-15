# Phase 6B: Deterministic Conversation Analytics Foundation

## Status

`COMPLETE` for the bounded deterministic analytics scope. All automated Phase
6B and repository regression gates passed. Phase 6A.3 remains `BLOCKED` pending
physical Android and iOS qualification and remains a production release gate.

The user-authorized sequencing decision permits later build phases to continue
with automated verification while physical qualification is deferred until the
application build is complete. This changes sequencing only. It does not weaken
the Phase 6A gates, qualify emulator evidence, modify native extraction, or
permit a production release without the missing physical evidence.

## Outcome

Phase 6B adds a pure deterministic backend domain engine over accepted
`conversation-events.v1` timelines. Equal event streams and reviewed quality
facts produce equal immutable `conversation-analytics.v1` results. Every metric
contains its formula, event inclusion/exclusion set, required fields,
unsupported conditions, structural evidence, and deterministic data quality.

The implementation adds no customer UI, public or internal API route, database
table, migration, persistence, cache, background job, mobile algorithm, model
provider, generated content, advice, scoring, or semantic inference.

## Architecture

```mermaid
flowchart LR
    A["Confirmed canonical event sequence"] --> B["Review, partial, and gap facts"]
    B --> C["DeterministicConversationAnalyticsEngine"]
    C --> D["Immutable versioned metric sections"]
    D --> E["Content-free evidence and quality metadata"]
```

The backend owns the single canonical algorithm. Mobile changes are unnecessary
in this phase and no duplicate Dart implementation exists. Future authorized
consumers may call this domain engine behind the existing owner/consent
boundary, but Phase 6B exposes no route.

## Contracts

`backend/app/domain/conversation_analytics.py` adds frozen, slotted v1 value
objects for:

- analytics input and explicit timeline gaps;
- conversation, message, participant, timing, question, reply, reaction, media,
  and structure sections;
- metric definitions and values;
- structural evidence references;
- deterministic quality metadata; and
- the complete analytics result.

The result has no wall-clock generation timestamp. Evidence contains only event
UUIDs, relationship UUIDs, and the calculation version. Unsupported metrics
return no value and always expose a stable reason.

## Engine behavior

`backend/app/domain/conversation_analytics_engine.py` implements only the
catalog in `Analytics-Specification.md`:

- communication, message, media, and marker counts;
- descriptive participation shares, session starts, initiations, and
  consecutive speaker runs;
- exact duration, active/inactive intervals, and response-latency aggregates;
- literal-question and explicit-reply relationship counts;
- reaction sent/received/type/target counts; and
- timeline-gap, duplicate, unknown, and structural-event counts.

Pending, rejected, unknown, duplicate, structural, deleted, edited, reply, and
reaction events follow their canonical inclusion rules. Missing or estimated
timestamps are never filled. Missing speakers are never guessed. Invalid
relationships are never repaired. Timeline gaps and partial inputs stay visible
through quality metadata.

## Privacy, security, and accessibility review

- The engine has no logger and tests confirm raw synthetic text and captions do
  not appear in results.
- No screenshot, OCR, prompt, participant name, source path/hash, device fact,
  deleted content, or message body enters evidence.
- Reaction type remains an in-memory derived value and is not logged or stored.
- No authentication, authorization, consent, ownership, deletion, permission,
  API, or database behavior changed.
- There is no UI, so no new visual, motion, screen-reader, text-scaling, contrast,
  or touch-target surface exists.

## Performance

The engine performs bounded deterministic passes after ordering the canonical
input and creates no network, database, OCR, or AI work. A standalone
content-free benchmark covers a 5,000-event synthetic timeline. Its output is
aggregate only and is not mixed with the Phase 6A OCR benchmark.

## Tests

`backend/tests/test_phase6b_deterministic_analytics.py` covers:

- the complete metric catalog and exact formulas;
- unsupported and reduced-quality states;
- timeline gaps, missing/estimated timestamps, and missing speakers;
- pending, rejected, partial, unknown, duplicate, deleted, and structural events;
- reactions, targets, invalid relationships, explicit replies, and orphan replies;
- structural evidence and calculation versions;
- immutable contracts and equal-input/equal-output regression;
- source-version rejection and catalog compatibility;
- raw-content-free results and zero engine logging; and
- a 5,000-event deterministic timeline.

The independent benchmark lives at
`backend/benchmarks/phase6b_analytics_benchmark.py`.

## Files created

- `backend/app/domain/conversation_analytics.py`
- `backend/app/domain/conversation_analytics_engine.py`
- `backend/tests/test_phase6b_deterministic_analytics.py`
- `backend/benchmarks/__init__.py`
- `backend/benchmarks/phase6b_analytics_benchmark.py`
- `docs/Analytics-Specification.md`
- `docs/phase-6b-deterministic-analytics-foundation.md`

## Expected unchanged boundaries

- Mobile changes: none.
- API changes: none.
- Database changes and migrations: none.
- Extraction/OCR changes: none.
- Canonical conversation-event model changes: none.
- Review Studio changes: none.
- Phase 6A fixtures, thresholds, and native runners: none.

## Verification results

The final automated pass produced these results:

- Flutter dependency resolution and both Dart formatting passes succeeded;
- `flutter analyze` returned no findings;
- all 82 Flutter tests passed;
- the seven-fixture Phase 6A provider-neutral reference benchmark passed;
- the Flutter release bundle built successfully and remained free of benchmark
  paths and synthetic fixture identifiers;
- Ruff format/check and lint passed across the backend;
- MyPy strict checking passed across 47 source files;
- `pip check` reported no broken requirements;
- all 56 backend tests passed with warnings treated as errors, including 13
  focused Phase 6B tests;
- the content-free benchmark processed 5,000 events over 20 iterations at about
  307,000 events per second on this workstation; this is a development
  measurement, not a release gate;
- a fresh isolated PostgreSQL database passed upgrade to head, downgrade to
  `20260714_0003`, re-upgrade, and Alembic drift checking;
- Docker Compose configuration, generated OpenAPI, 25 Pydantic schemas, 14
  tracked JSON documents/schemas, CI YAML, prohibited-feature/logging scans,
  API/migration boundary checks, release-artifact privacy scans, and
  `git diff --check` passed.

The first migration drift check reused an older local Docker database whose
Alembic stamp did not match one pre-existing Phase 5 column. The repository was
not changed to hide or repair that unrelated local volume. The required cycle
was repeated in a fresh isolated database and passed. The stale default local
database remains an environment cleanup item if it is reused.

## Known limitations

- Question counting recognizes only a literal `?`; it is intentionally not
  semantic language analysis.
- Answered-question status requires an explicit canonical `reply_target`; the
  engine does not infer an answer from text.
- The fixed 30-minute active/inactive session boundary is mechanical and must
  never be described as engagement or interest.
- Analytics remain internal, derived, and non-persistent.
- The default local Docker database volume predates the current migration
  history and should be recreated or repaired deliberately before it is used;
  the fresh isolated verification database is clean.
- Physical Android/iOS extraction, performance, cancellation, cleanup, and
  accessibility qualification remain unverified because Phase 6A.3 is blocked.

## Exclusions confirmed

No dashboard, chart, score, relationship-health claim, green/red signal,
semantic analysis, AI, GPT, coaching, Communication DNA, reply generation,
first-message generation, analytics history, persistence, cloud/offline sync,
OCR modification, fixture/threshold change, or physical-device qualification is
implemented.
