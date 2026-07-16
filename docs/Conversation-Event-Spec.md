# ConvoCoach Conversation Event Specification

**Version:** 1.0

**Status:** Phase 6A.1 runtime implemented; native qualification outstanding

**Owner:** ConvoCoach Engineering

**Last updated:** July 2026

**Related documents:** `master-build-prompt.md`, `AI-System-Architecture.md`,
`AI-Scoring-Engine.md`, `phase-5-conversation-extraction.md`,
`phase-6a-native-extraction-qualification.md`,
`phase-6a1-conversation-event-runtime-foundation.md`

## 1. Purpose

This document defines the canonical event model used by ConvoCoach for imported
dating conversations. A conversation is not made only of text messages. It may
contain:

- text messages;
- emoji-only messages;
- reactions;
- images, videos, GIFs, stickers, voice notes, audio, and documents;
- links, locations, contact cards, polls, and payment requests;
- calls and missed or declined calls;
- deleted messages and edit markers;
- reply references;
- system notices, date or unread separators, and encryption notices; and
- unknown or unsupported content.

The extraction engine must classify these items correctly before analytics or AI
analysis begins. This specification ensures that:

1. reactions are not counted as separate messages;
2. calls are not treated as text;
3. deleted-message notices are preserved without inventing content;
4. media events remain distinguishable from messages;
5. uncertain items remain unknown instead of being fabricated;
6. downstream analytics use the correct event types; and
7. every event retains provenance and confidence information.

## 2. Core Principle

The extraction pipeline must produce conversation events first.

```text
Screenshot
    ↓
OCR and layout recognition
    ↓
Conversation events
    ↓
Normalization
    ↓
Confirmed conversation
    ↓
Deterministic analytics
    ↓
Semantic AI analysis
```

The system must not force every recognized item into a text-message model. No
analytics, scoring, or generation may run until the user has reviewed and
confirmed the normalized event sequence.

## 3. Canonical Event Types

The supported canonical event types are:

```text
text_message
emoji_message
reaction
image
video
gif
sticker
voice_note
audio
document
link
location
contact_card
poll
payment_request
call_started
call_ended
missed_call
declined_call
deleted_message
edited_message_marker
reply_reference
system_message
date_separator
unread_separator
encryption_notice
member_event
unknown
```

New event types may be added only through:

1. a schema update;
2. migration review;
3. documentation update;
4. analytics-impact review; and
5. backward-compatibility review.

## 4. Base Conversation Event Schema

Every event uses the following common shape:

```json
{
  "id": "uuid",
  "conversation_id": "uuid",
  "position": 1,
  "event_type": "text_message",
  "speaker": "user",
  "timestamp": "2026-07-14T19:10:00+05:30",
  "timestamp_is_estimated": false,
  "raw_timestamp_text": "7:10 PM",
  "source_image_index": 0,
  "source_region_id": "region-12",
  "ocr_confidence": 0.97,
  "classification_confidence": 0.92,
  "speaker_confidence": 0.99,
  "timestamp_confidence": 0.93,
  "relationship_confidence": null,
  "requires_review": false,
  "is_deleted": false,
  "metadata": {}
}
```

Required fields are `id`, `conversation_id`, `position`, `event_type`,
`speaker`, `timestamp`, `timestamp_is_estimated`, `source_image_index`,
`ocr_confidence`, `classification_confidence`, `speaker_confidence`,
`timestamp_confidence`, `requires_review`, and `metadata`.
`relationship_confidence` is required when an event asserts a relationship. A
required field may contain `null` when this specification explicitly permits an
unresolved value; it must not be omitted or fabricated. Provider-unavailable
confidence must be represented explicitly and must require review rather than
being replaced with a made-up score.

## 5. Speaker Values

Allowed speaker values are:

```text
user
other
system
unknown
```

- `user` means the owner of the imported conversation.
- `other` means the conversation partner.
- `system` means the messaging platform or a system notice.
- `unknown` must be used when speaker assignment is uncertain.
- The extraction engine must never guess a speaker when layout evidence is weak.
- The Review Studio must allow speaker correction.

## 6. Text Message

**Event type:** `text_message`

A text message represents normal textual content sent by a participant.

```json
{
  "event_type": "text_message",
  "speaker": "user",
  "text": "How was your weekend?",
  "metadata": {
    "language": "en",
    "contains_question": true
  }
}
```

Rules:

- Preserve original spelling, punctuation, and emojis embedded in text.
- Do not rewrite Hinglish or correct grammar automatically.
- Do not merge separate bubbles unless evidence supports it.
- Do not split one bubble into multiple events without evidence.

It counts as one message and one participant contribution. Its words,
characters, questions, and visible timestamp may contribute to the applicable
deterministic metrics.

## 7. Emoji-Only Message

**Event type:** `emoji_message`

A standalone emoji or emoji sequence in its own message row is an emoji message,
not a reaction.

```json
{
  "event_type": "emoji_message",
  "speaker": "other",
  "text": "😂",
  "metadata": {
    "emoji_count": 1
  }
}
```

It counts as one message and one participant contribution and may be a limited
tone signal. It must not be classified as a reaction unless UI evidence shows
that it is attached to another event.

## 8. Reaction

**Event type:** `reaction`

A reaction is an emoji acknowledgement attached to another event, such as a
heart, laugh, thumbs-up, or surprise reaction.

```json
{
  "event_type": "reaction",
  "speaker": "other",
  "metadata": {
    "reaction": "❤️",
    "target_event_id": "uuid",
    "target_text_excerpt": "Coffee tomorrow?"
  }
}
```

- A reaction must reference its target event where detectable.
- If the target cannot be identified, `target_event_id` remains `null` and the
  reaction has `requires_review: true`.
- A reaction must remain visually attached to its target in Review Studio.
- It is not a new message, reply, question, or topic initiation.
- After confirmation, it may contribute only limited evidence of acknowledgement
  or tone; it must never be treated as proof of another person's internal state.

## 9. Image Event

**Event type:** `image`

```json
{
  "event_type": "image",
  "speaker": "user",
  "metadata": {
    "caption": "This was from Goa",
    "media_count": 1,
    "content_available": false
  }
}
```

- Do not infer image content unless the user explicitly requests a supported,
  consented analysis.
- Do not retain image bytes by default.
- Preserve visible caption text and only the minimal metadata needed for
  conversation continuity.
- Count the image as one conversational contribution. Do not count image content
  as text; only a visible caption contributes text.

## 10. Video Event

**Event type:** `video`

Video follows the image rules. Metadata may include a visible caption and
duration, for example:

```json
{
  "duration_seconds": 18,
  "caption": "Look at this"
}
```

Private video content is not analyzed during the MVP.

## 11. GIF Event

**Event type:** `gif`

- Treat a GIF as a media contribution.
- Preserve a visible caption if present.
- Do not infer its meaning with certainty.
- It may support limited, explicitly uncertain tone interpretation in a later
  authorized phase.

## 12. Sticker Event

**Event type:** `sticker`

- A sticker is not a text message.
- It may carry platform-specific visual meaning.
- If its meaning cannot be classified, preserve it as a sticker with unknown
  meaning.

## 13. Voice Note

**Event type:** `voice_note`

```json
{
  "duration_seconds": 42,
  "transcript": null,
  "transcript_consent": false
}
```

- Do not transcribe automatically without explicit consent.
- Do not fabricate transcript content.
- Preserve visible duration.
- Treat it as conversational effort, not as text.

## 14. Audio Event

**Event type:** `audio`

Use this type for non-voice-note audio attachments. Do not assume the attachment
contains speech.

## 15. Document Event

**Event type:** `document`

```json
{
  "file_name": "resume.pdf",
  "file_type": "application/pdf"
}
```

Do not inspect document contents during conversation extraction.

## 16. Link Event

**Event type:** `link`

Use this type when a message is primarily a URL or link preview.

```json
{
  "url_domain": "example.com",
  "has_preview": true
}
```

A confirmed link event may be passed to the safety-classification boundary in a
later authorized phase. Extraction must not automatically visit links.

## 17. Location Event

**Event type:** `location`

- Preserve only the visible label or place name.
- Do not infer a more precise location than the user uploaded.
- Do not store live-location data.
- Do not treat the location as a normal text message.

## 18. Contact Card

**Event type:** `contact_card`

- Redact phone numbers where practical.
- Avoid retaining unnecessary third-party personal data.
- Do not expose contact details in analytics.

## 19. Poll

**Event type:** `poll`

```json
{
  "question": "Coffee or dinner?",
  "options": ["Coffee", "Dinner"],
  "selected_option": "Coffee"
}
```

Poll options are metadata and must not be counted as separate messages.

## 20. Payment Request

**Event type:** `payment_request`

This type represents requests for money, UPI transfers, payment links, or
reimbursement.

- Preserve minimal metadata.
- Pass only confirmed, minimized data to safety analysis in an authorized phase.
- Redact account numbers and UPI IDs where practical.
- Do not expose payment identifiers unnecessarily.
- Do not count a payment request as positive engagement by default.
- It may trigger a safety caution depending on the confirmed context.

## 21. Call Events

Supported types are `call_started`, `call_ended`, `missed_call`, and
`declined_call`.

```json
{
  "event_type": "missed_call",
  "speaker": "other",
  "timestamp": "2026-07-14T21:05:00+05:30",
  "metadata": {
    "call_type": "audio"
  }
}
```

- Do not count calls as text messages.
- Preserve visible duration.
- A confirmed call event may supply contextual sequence evidence in a later
  authorized phase.
- Do not infer call quality or relationship health.

## 22. Deleted Message

**Event type:** `deleted_message`

```json
{
  "event_type": "deleted_message",
  "speaker": "other",
  "text": null,
  "metadata": {
    "platform_text": "This message was deleted"
  }
}
```

- Never reconstruct or speculate about deleted content.
- Preserve only the visible deletion marker.
- Treat it as a conversation event, not readable message content.

## 23. Edited Message Marker

**Event type:** `edited_message_marker`

- Attach the marker to the edited event where possible.
- Do not create a separate conversational message.
- Preserve the visible edited status.

## 24. Reply Reference

**Event type:** `reply_reference`

```json
{
  "target_event_id": "uuid",
  "quoted_text": "You said you like trekking"
}
```

- A reply reference is not a separate message.
- Attach it to the parent participant event.
- Preserve the reply relationship for context.

## 25. System Message

**Event type:** `system_message`

Examples include a disappearing-message change, chat-theme change, screenshot
notification, or account-joined notice.

- The speaker must be `system`.
- It does not count as participant effort.
- Preserve it only when relevant to conversation context.

## 26. Date Separator

**Event type:** `date_separator`

Examples include `Today`, `Yesterday`, and `14 July 2026`.

- It is not a message.
- Use it only to resolve timestamps.
- It may supply date context to following time-only events.
- Hide it from the primary Review Studio message count by default.

## 27. Unread Separator

**Event type:** `unread_separator`

Examples include `2 unread messages` and `New messages`. It is structural
context and is not a message.

## 28. Encryption Notice

**Event type:** `encryption_notice`

It may later be implemented as a subtype of `system_message`, but it must remain
distinguishable when useful.

## 29. Member Event

**Event type:** `member_event`

Examples include a participant being added or removed, or a group name being
changed. This exists for forward compatibility; group chats are outside the MVP.

## 30. Unknown Event

**Event type:** `unknown`

Use this safety valve when extraction cannot classify an item confidently.

- Preserve source provenance and any visible text.
- Set `requires_review: true`.
- Do not guess.
- Exclude it from deterministic analytics until the user confirms its type.

An unknown event is valid output, not a processing error.

## 31. Event Relationships

Supported relationship types are:

```text
reaction_target
reply_target
edit_target
media_caption
call_pair
system_context
duplicate_of
```

```json
{
  "id": "reaction-1",
  "event_type": "reaction",
  "metadata": {
    "target_event_id": "message-8"
  }
}
```

Relationships must retain their own classification confidence where applicable.

## 32. Event Normalization Rules

The normalizer must:

1. preserve event order;
2. attach reactions to target events;
3. attach reply references to parent participant events;
4. preserve deleted-message markers;
5. identify duplicates without destroying provenance;
6. retain unknown events for review;
7. preserve system events separately;
8. avoid turning reactions into messages;
9. avoid turning date separators into messages; and
10. avoid inventing content.

## 33. Analytics Inclusion Matrix

| Event type | Counts as message | Counts for response time | Counts as engagement | Requires semantic review |
| --- | --- | --- | --- | --- |
| `text_message` | Yes | Yes | Yes | Sometimes |
| `emoji_message` | Yes | Yes | Yes | Sometimes |
| `reaction` | No | No | Limited | Yes |
| `image` | Yes | Yes | Yes | Sometimes |
| `video` | Yes | Yes | Yes | Sometimes |
| `gif` | Yes | Yes | Yes | Sometimes |
| `sticker` | Yes | Yes | Yes | Sometimes |
| `voice_note` | Yes | Yes | Yes | Sometimes |
| `deleted_message` | No | No | Limited | Yes |
| `missed_call` | No | No | Contextual | Yes |
| `system_message` | No | No | No | Rarely |
| `date_separator` | No | No | No | No |
| `unknown` | No until confirmed | No | No | Yes |

The analytics engine must follow this matrix. Here, engagement means only an
observable contribution category; it is not a score of interest, compatibility,
relationship health, or likely success.

## 34. Review Studio Behavior

The Review Studio displays each type distinctly:

| Event | Presentation |
| --- | --- |
| Text or emoji message | Conversation bubble |
| Reaction | Small reaction chip attached to its target |
| Media | Media placeholder card |
| Voice note | Voice-note card with visible duration |
| Call | Timeline event card |
| Deleted message | Muted placeholder |
| Unknown | Warning card requiring review |

Users must be able to:

- change an event type;
- attach a reaction to a target event;
- detach an incorrect reaction;
- convert an emoji message to a reaction;
- convert a reaction to an emoji message;
- delete and restore an event;
- correct the speaker and timestamp; and
- mark an event as unknown.

Deleting an event in Review Studio is an editable draft operation. Persistence,
if later authorized, must retain a bounded undo path and follow the product's
deletion requirements.

## 35. Confidence Rules

Every event has:

- OCR confidence;
- classification confidence;
- speaker confidence;
- timestamp confidence; and
- relationship confidence where applicable.

```json
{
  "ocr_confidence": 0.98,
  "classification_confidence": 0.62,
  "speaker_confidence": 0.99,
  "timestamp_confidence": 0.74,
  "requires_review": true
}
```

Low or unavailable confidence in a critical field must trigger review.
Conversation readiness describes data quality only and must not imply relationship
health, compatibility, interest, or likely success.

## 36. Reaction Classification Rules

An item is more likely to be a reaction when it:

- overlaps or touches a participant event bubble;
- is visually smaller than normal message text;
- appears inside a reaction chip;
- has no independent bubble;
- sits directly beneath or beside another event; or
- matches a known reaction-glyph pattern.

An item is more likely to be an emoji message when it:

- appears inside its own message bubble;
- occupies a normal message row;
- has an independent timestamp; or
- follows normal speaker alignment.

When evidence remains insufficient, use `event_type: unknown` and
`requires_review: true`.

## 37. Duplicate Detection Rules

Overlapping screenshots may repeat events. Duplicate detection should consider:

- normalized text;
- event type;
- speaker;
- visible or parsed timestamp;
- bounding-box location;
- screenshot overlap position; and
- neighboring events.

A suspected duplicate retains provenance until the user reviews it. Reactions
must not be deduplicated against emoji messages merely because the glyph matches.

## 38. Timestamp Rules

- Never fabricate a timestamp.
- Preserve raw visible timestamp text.
- Resolve time-only values using the nearest valid date separator.
- Keep unresolved timestamps `null`.
- Keep `timestamp_is_estimated` false unless a documented estimation rule was
  applied.
- Never present an estimated timestamp as exact.

## 39. Privacy Rules

- Media and screenshot bytes are not retained by default.
- Private media is not analyzed without explicit user action, consent, and an
  authorized product phase.
- Minimize contact data.
- Redact payment identifiers where practical.
- Do not put unnecessary personal data in event metadata.
- Never log raw content, screenshot paths, source hashes, or full prompts.
- Benchmark fixtures must be original and synthetic.
- Clear imported screenshot bytes when an import is abandoned or after the user
  saves the reviewed normalized events.
- Never send screenshot paths or bytes to the backend.

## 40. Backend Persistence

Phase 6A.1 implements `conversation_events` with these columns:

```text
id
conversation_id
position
event_type
speaker
text
timestamp
timestamp_is_estimated
raw_timestamp_text
source_image_index
source_region_id
ocr_confidence
classification_confidence
speaker_confidence
timestamp_confidence
relationship_confidence
requires_review
metadata_json
created_at
updated_at
deleted_at
```

Relationships such as reactions and replies use
`conversation_event_relationships` with these candidate columns:

```text
id
source_event_id
target_event_id
relationship_type
confidence
metadata_json
```

Revision `20260715_0004` owns events through the conversation foreign key,
enforces bounded metadata at the API boundary, cascades deletion, supplies
indexes and closed constraints, and downgrades without touching `messages`.
The versioned endpoint is documented in
`phase-6a1-conversation-event-runtime-foundation.md`.

## 41. Backward Compatibility

Existing `messages` records must not be silently rewritten. Phase 6A.1 uses this
reversible compatibility path:

1. retain the current `messages` table temporarily;
2. introduce conversation events;
3. project existing messages to `text_message` events only at read time;
4. preserve old identifiers where practical;
5. migrate analytics gradually; and
6. deprecate the message-only model only after verification.

The implemented migration is reversible. Analytics migration and message-table
deprecation remain separately authorized future work.

## 42. Testing Requirements

Future event-model behavior requires deterministic, synthetic tests covering:

- reaction versus emoji-message classification;
- reaction-target attachment;
- deleted-message preservation;
- media and call classification;
- unknown-event fallback;
- duplicate detection and event ordering;
- timestamp resolution without fabrication;
- every Review Studio conversion;
- analytics inclusion rules;
- backward-compatible migration and downgrade behavior;
- privacy cleanup; and
- synthetic fixture coverage.

No real conversation may be used as a fixture. Documentation-only changes do not
claim these future behavioral tests are implemented or passing.

## 43. Known Limitations

The MVP may not reliably detect:

- complex sticker meanings;
- animated GIF semantics;
- voice-note content;
- hidden message edits;
- deleted content;
- nested replies;
- platform-specific proprietary event types;
- ambiguous emoji placement; or
- partially cropped reactions.

These limitations must be surfaced through confidence and review flags.

## 44. Definition of Done

The conversation-event architecture baseline is complete when:

- all supported event types are documented;
- reactions are no longer specified as messages;
- event relationships are defined;
- analytics inclusion rules are defined;
- Review Studio behavior is defined;
- a future persistence strategy is defined;
- a reversible migration strategy is documented;
- confidence requirements are defined;
- privacy rules are included;
- required tests are specified; and
- `unknown` remains a valid fallback.

Phase 6A.1 delivers the schema, migration, contracts, extraction and
normalization behavior, Review Studio behavior, privacy lifecycle, and host
tests. Analytics changes are deliberately absent. Physical Android/iOS
qualification remains outstanding, so this foundation must not be described as
native event-classification qualification or used to authorize Phase 6B.
