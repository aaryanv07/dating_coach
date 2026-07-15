# Phase 4: Conversation Import and Review Studio

## Scope

Phase 4 prepares conversation data for later features. It does not interpret a
conversation, infer intent, calculate relationship health, generate replies, or
call an AI provider.

Implemented journey:

1. Choose screenshots or pasted text.
2. Validate type, count, and size at the mobile boundary.
3. Hold screenshot bytes in temporary in-memory device storage.
4. Extract messages through a replaceable `OcrEngine`; Phase 4 ships a realistic
   deterministic mock.
5. Review every message block and its speaker, timestamp, confidence, and source.
6. Resolve data-quality checks and explicitly consent to storage.
7. Normalize active messages, clear temporary screenshots, and persist structured
   text plus non-content source-disposal metadata.
8. Return to Conversations and reopen the saved normalized conversation.

## Mobile boundaries

`features/conversation_import` is split into:

- `domain`: review message model, OCR/text-parser contracts, readiness, and
  normalization;
- `data`: system multi-image picker, temporary source store, and mock OCR/parser;
- `application`: Riverpod import state, bounded undo/redo history, validation,
  operations, and save orchestration;
- `presentation`: import choice, screenshot drop/picker, paste input, source
  preview, and Review Studio.

The image picker and drag/drop adapter both produce `TemporaryImportSource`
objects. UI code does not know which OCR implementation consumes them. Replacing
the mock with an on-device ML Kit adapter must not change Review Studio.

## Review operations

Each message has an ID, speaker, text, optional timestamp, estimated-timestamp
flag, optional OCR confidence, optional source screenshot index, and status. The
editor supports edit, delete, restore, merge with next, split, change/swap
speaker, duplicate, move, add, undo, and redo. Deleted blocks stay in editor
history until save so they can be restored. Undo history is capped at 50
snapshots.

Messages below 80 percent OCR confidence remain visibly marked `Needs review`
until edited. Messages above 95 percent receive no confidence decoration. Source
indices open the corresponding temporary screenshot directly.

## Readiness

Readiness is deterministic data quality. It is not a relationship, interest,
compatibility, or outcome score. The 100 points are:

| Check | Points |
| --- | ---: |
| OCR confidence/review | 30 |
| Non-empty messages | 20 |
| Speaker assignment | 20 |
| Screenshot order | 10 |
| Duplicate messages | 10 |
| Timestamp availability | 5 |
| At least two messages | 5 |

The save threshold is 85. Missing messages, empty messages, unassigned speakers,
bad screenshot order, duplicates, or unresolved low-confidence OCR are blocking
even when the numeric total would otherwise pass. Timestamps improve quality but
do not block a pasted conversation.

## Persistence and privacy

The Flutter Phase 4 repository remains an in-memory mock. It stores normalized
messages and allows them to be listed and reopened during the app session.
Screenshot bytes are cleared on cancellation and after successful save.

The backend adds `POST /api/v1/conversations/{id}/confirm`. It accepts normalized
messages and source-disposal metadata only. It rejects screenshot bytes, paths,
and URLs by having no fields for them. Active `save_conversation_history` consent
and readiness of at least 85 are required. Owner scope is enforced before an
atomic replacement of draft content.

Alembic revision `20260714_0002` adds import state to conversations and messages,
plus `conversation_sources`. A screenshot source can only be persisted with
`storage_status=deleted`; pasted text uses `not_stored`.

## Explicit exclusions

No GPT, OpenAI, AI analysis, Conversation Health, dashboard, interest score,
reply suggestion, first-message generation, profile import, payment, or
subscription behavior is included. Phase 5 adds real on-device OCR and image
preprocessing without changing Review Studio. Durable mobile storage, HTTP
mobile transport, and production device audits remain later work.
