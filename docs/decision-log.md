# Decision Log

## 2026-07-15: Phase 5 is extraction, not analysis

The explicit implementation request defines Phase 5 as the Real Conversation
Extraction Engine even though the static roadmap in `master-build-prompt.md`
labels Phase 5 as analysis. The explicit request controls this phase. No
analysis, scoring, generation, OpenAI, or GPT behavior is introduced.

## 2026-07-15: On-device screenshot processing is the primary path

The AI architecture previously described mandatory backend object storage before
OCR while also naming on-device ML Kit as preferred. For the current mobile
path, screenshots remain temporary on-device, ML Kit runs on-device, and only
user-confirmed structured messages reach FastAPI. Private object storage remains
a possible future backend fallback and is not part of Phase 5.

## 2026-07-15: ML Kit does not own chat layout interpretation

The `google_mlkit_text_recognition` bridge is isolated behind
`TextRecognitionProvider`. It supplies text structure, boxes, and confidence.
Grouping, speaker inference, timestamp resolution, screenshot ordering, and
overlap detection remain provider-neutral strategies because ML Kit is not a
complete chat-bubble detector.

## 2026-07-15: Extraction idempotency is private and session-scoped

Repeated requests are keyed with SHA-256 digests of temporary source bytes plus
pipeline versions. The coordinator stores at most three completed results in
memory. Source digests are not logged, sent to analytics, or persisted because a
long-lived screenshot fingerprint would exceed the purpose of provenance.
