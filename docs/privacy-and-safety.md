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

## Phase 4 and Phase 5 controls

- Authenticated identities are derived from a verified bearer token, never a
  client-supplied user ID.
- Every conversation lookup includes the authenticated owner ID. A foreign
  resource returns the same 404 response as a missing resource.
- Consent decisions are append-only records containing type, grant/withdrawal,
  policy version, and timestamp.
- Conversation-list responses include counts and labels but no message bodies.
- Deleting a conversation immediately removes its participants and messages.
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
- Pasted text and OCR output remain editable before storage. Nothing is analyzed
  in this phase, and confirmation requires an explicit history-retention choice.
- Backend source rows retain only MIME type, byte size, order, and a mandatory
  `deleted` or `not_stored` status. There is no path, object key, URL, or blob.
- Readiness is labeled and implemented as data quality only.

## Product safety

Coaching should help users communicate honestly and respect boundaries. The
product must not optimize for persistence after rejection, conceal identity,
manufacture emotional dependency, or automate pressure. Generated content must
remain a draft and should be framed as one possible response, not the correct
interpretation of another person.

Features involving crisis, abuse, self-harm, threats, stalking, minors, or sexual
coercion require dedicated policy and escalation design before implementation.
The current phase contains on-device OCR and data-quality readiness. It contains
no semantic AI, inference about people or relationships, screenshot upload, or
generated coaching.
