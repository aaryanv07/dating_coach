# Phase 6A.1: Conversation Event Runtime Foundation

## Outcome

Phase 6A.1 implements the reviewed event specification as a typed runtime while
preserving the Phase 4/5 message contract. It does not add deterministic
analytics, semantic AI, scoring, generation, or Phase 6B behavior.

The implementation keeps `messages` unchanged and introduces events beside it.
Existing consumers can continue to use the current conversation detail and
message confirmation routes. Event-aware consumers use the versioned
`conversation-events.v1` contract.

## Backend runtime

Alembic revision `20260715_0004` adds:

- `conversation_events`, owned through its required conversation foreign key;
- `conversation_event_relationships`, linked through source and target event
  foreign keys;
- closed checks for all event, speaker, and relationship values;
- bounds for positions, source indexes, and five distinct confidence fields;
- system-speaker and unknown-review invariants;
- conversation/type, source, and target indexes; and
- cascade deletion for conversation, account, and event deletion.

The downgrade removes only the two event tables. It never drops, copies,
rewrites, or backfills `messages`.

The FastAPI event surface is:

| Method | Endpoint | Behavior |
| --- | --- | --- |
| `GET` | `/api/v1/conversations/{conversation_id}/events` | Returns persisted events or an explicit read-time legacy projection |
| `PUT` | `/api/v1/conversations/{conversation_id}/events` | Atomically replaces only the v1 event sequence after active history consent |

Foreign and missing conversation IDs return the same 404. List responses remain
content-free and retain their legacy message count. If no event rows exist, the
GET route projects each legacy message to `text_message` without storing a
second copy; `compatibility_mode` reports `message_projection`. Once event rows
exist, it reports `persisted_events`.

Event metadata is JSON, bounded to 16 KB and four nested levels. The API rejects
known raw-source, direct-payment-identifier, prompt, path, and byte fields.
Relationships must reference unique event IDs inside the same replacement
payload. Resolved reactions require a `reaction_target`; unresolved reactions
remain reviewable rather than receiving a guessed target.

## Mobile runtime

Flutter now has exhaustive typed enums for the canonical event and relationship
vocabularies, typed normalized domain records, and v1 DTO serializers. The
import state exposes the full event sequence while retaining `messages` as a
compatibility accessor for existing tests and callers. Editor history remains
immutable at commit boundaries and bounded to 50 snapshots.

The replaceable deterministic event classifier uses visible text, geometry, and
explicit parser hints to preserve:

- standalone emoji rows as `emoji_message`;
- compact emoji attached to a preceding bubble as `reaction` plus a target
  relationship;
- date and unread separators;
- deletion, encryption, call, selected media, edited-marker, link, system, and
  unknown-safe behavior; and
- separate OCR, classification, speaker, timestamp, and relationship evidence.

These values describe deterministic rule evidence; they are not claims of
production accuracy. A reaction's speaker is left `unknown` when geometry does
not identify the reactor. Provider-unavailable or ambiguous items require user
review.

The extraction result contains a full `events` sequence and a legacy `messages`
projection. Reactions, reply/edit relationships, system notices, separators,
deleted markers, calls, and unknown items do not enter the projection. This
fixes the synthetic compact-heart regression where a reaction was previously
returned as an extra message.

## Review Studio and normalization

Review Studio renders an event type and icon, message-inclusion label, speaker,
visible text, timestamp, source image, uncertainty warning, and target chip. A
user can:

- change any event type;
- convert emoji messages and reactions by changing type;
- attach or detach reaction, reply, and edit targets;
- correct the speaker, timestamp, and visible timestamp text;
- edit supported visible text;
- delete and restore an event;
- classify an unknown item; and
- retain merge, split, duplicate, move, undo, and redo for applicable content.

Structural events use the system speaker. Unknown or unattached relationship
events block readiness. Readiness still describes data quality only and counts
only participant contribution types as messages.

Normalization is pure and deterministic for a fixed review snapshot. It
preserves event order, type, soft-deletion time, provenance, confidence,
metadata, and relationships. The legacy message projection contains only active
participant contributions with user/other speakers and non-empty visible text.
Reaction and emoji events therefore cannot deduplicate or count as one another.

## Privacy and safety

- Screenshot bytes and paths remain temporary and on-device.
- Neither the event endpoint nor its metadata accepts screenshot content or
  source paths.
- Conversation event reads and writes are owner scoped and consent gated.
- Conversation and account deletion cascade through event rows and
  relationships.
- List responses expose no event or message text.
- No prompt, message body, metadata payload, source digest, or credential is
  logged.
- No analytics, scoring, AI provider, or generation path consumes these events
  in Phase 6A.1.

## Verification and limits

The backend suite covers schema registration and cascades, v1 validation,
consent, ownership-hiding 404s, metadata rejection, legacy projection,
relationship persistence, and proof that event replacement leaves messages
unchanged. Flutter tests cover reaction-versus-emoji classification, reaction
targeting, event-aware readiness, deterministic normalization, DTO round trips,
Review Studio regressions, and the Phase 6A reference benchmark.

Physical Android and iOS ML Kit qualification remains the outstanding Phase 6A
release gate. Host and deterministic fixture results do not establish native OCR
accuracy, classifier calibration, or performance on real devices. No Phase 6B
work is authorized by this foundation.

### Commands executed

The final verification pass used the repository commands below. Python commands
used the temporary project environment at `/tmp/convocoach-py313-venv`; it is
not part of the repository.

```text
cd apps/mobile
flutter pub get
dart format .
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter test benchmark/phase6a_reference_benchmark_test.dart
flutter build bundle --release

cd <repository-root>
/tmp/convocoach-py313-venv/bin/ruff format backend
/tmp/convocoach-py313-venv/bin/ruff format --check backend
/tmp/convocoach-py313-venv/bin/ruff check backend
cd backend
/tmp/convocoach-py313-venv/bin/mypy app tests
/tmp/convocoach-py313-venv/bin/pytest -W error
/tmp/convocoach-py313-venv/bin/pip check

DATABASE_URL=<isolated-PostgreSQL-URL> /tmp/convocoach-py313-venv/bin/alembic upgrade head
DATABASE_URL=<isolated-PostgreSQL-URL> /tmp/convocoach-py313-venv/bin/alembic downgrade 20260714_0003
DATABASE_URL=<isolated-PostgreSQL-URL> /tmp/convocoach-py313-venv/bin/alembic upgrade head
DATABASE_URL=<isolated-PostgreSQL-URL> /tmp/convocoach-py313-venv/bin/alembic check

docker compose --env-file .env.example config --quiet
git diff --check
```

The final backend run passed Ruff formatting and lint, MyPy, `pip check`, and all
43 Pytest tests with warnings treated as errors. The final Flutter run passed
formatting, analysis, all 73 tests, the Phase 6A reference benchmark, and the
release bundle build. The PostgreSQL run used an isolated temporary database and
passed initial upgrade, downgrade to `20260714_0003`, re-upgrade, and Alembic's
no-schema-drift check. Compose validation, CI YAML parsing, JSON parsing, schema
generation, prohibited-feature/logging scans, and `git diff --check` also
passed.

### Environment and deferred evidence

- Android SDK tooling was not available (`adb` was absent), and Flutter listed
  no Android device.
- The `xcodebuild` shim was present, but full Xcode was unavailable because the
  active developer directory was Command Line Tools. CocoaPods was absent.
- No physical Android or iOS testing occurred.
- ML Kit reaction classification was not tested natively. Only original
  synthetic fixtures and the content-free reference harness were used.
- Existing message compatibility remains active through unchanged message
  routes and an explicit read-time event projection when no stored events
  exist. No dual-write was introduced, and the event route never merges stored
  message rows and event rows into a hidden dual-read result.
- The migration is reversible and performs no legacy backfill. A coordinated
  deploy remains necessary, and downgrading after new event-only data is stored
  intentionally removes those new event tables and their data; it does not
  affect legacy messages.
- Phase 6A.2 now provides the repeatable Android/iOS readiness, runner, schema,
  and comparison infrastructure. Physical qualification gates remain
  outstanding, so the product is not production-qualified for native extraction
  or reaction detection.
- Phase 6B has not started.
