# API Contracts

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
