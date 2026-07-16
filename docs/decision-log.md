# Decision Log

## 2026-07-15: Native tool setup does not expand Phase 6A.3 scope

Android Studio 2026.1.2, the Flutter-required Android SDK/ADB components and
licenses, and CocoaPods 1.17.0 are installed. Android readiness is now blocked
only by a physical device, while iOS still needs full Xcode and a physical
iPhone. An APK preflight revealed an existing `irondash_engine_context` 0.5.5
CargoKit incompatibility with Gradle 9.1. Flutter's attempted minimum-SDK rewrite
was reverted. The production dependency/build correction requires separate
authorization and Phase 6B remains closed.

## 2026-07-15: Phase 6A.3 remains blocked at physical prerequisites

The Phase 6A.3 execution used the existing unchanged qualification runner and
stopped before native benchmark execution. Android had no SDK or physical
device; iOS had no complete Xcode, CocoaPods, or physical device. Host reference
and repository regression checks remain green, but they cannot substitute for
two consecutive physical runs, native reaction/accuracy/performance evidence,
or physical accessibility smoke checks. No runtime behavior changed and Phase
6B must not start until both platform suites pass every documented gate.

## 2026-07-15: Phase 6A.2 makes native qualification truthful and repeatable

The repository now owns Android, iOS, and common qualification runners, a
tool/device capability detector, benchmark session evidence, a strict v2 JSON
contract, explicit PASS/BLOCKED evaluation, and previous/current regression
comparison. A platform is ready only with Flutter, its complete native toolchain,
and a supported physical device. Simulator/host evidence cannot satisfy the
native gate. Device IDs and user-assigned names remain in-memory runner inputs
and are omitted from reports. This phase changes no customer runtime, backend
API, migration, analytics, AI, scoring, generation, payment, or subscription
behavior.

## 2026-07-15: Typed-event qualification uses expanded original fixtures

Two new original fixtures cover media placeholders, deleted/system events,
mixed English/Hinglish and Roman Hindi, emoji-heavy and reaction-heavy layouts,
and low contrast. The benchmark now gates typed-event classification accuracy
alongside extraction accuracy. Visual reaction overlays are explicit ground
truth and only enter classification expectations when marked as recognized OCR
text; this prevents decorative density from becoming fabricated transcript
content.

## 2026-07-15: Phase 6A.1 implements events beside legacy messages

`Conversation-Event-Spec.md` establishes the architecture baseline for typed
conversation events, relationships, confidence, Review Studio behavior,
analytics inclusion, privacy, and reversible persistence. The explicit Phase
6A.1 authorization introduces event tables, a `conversation-events.v1` endpoint,
typed extraction output, deterministic classification, and Review Studio event
corrections. Legacy messages are not backfilled or rewritten; event GET performs
an explicit read-time projection only when needed. Analytics and intelligence
remain unauthorized, and physical native qualification remains outstanding.

## 2026-07-15: Phase 5 is extraction, not analysis

The explicit implementation request defines Phase 5 as the Real Conversation
Extraction Engine even though the static roadmap in `master-build-prompt.md`
labels Phase 5 as analysis. The explicit request controls this phase. No
analysis, scoring, generation, OpenAI, or GPT behavior is introduced.

## 2026-07-15: On-device screenshot processing is the primary path

The AI architecture previously described mandatory backend object storage before
OCR while also naming on-device ML Kit as preferred. For the current mobile
path, screenshots remain temporary on-device, ML Kit runs on-device, and only
user-confirmed structured messages or Phase 6A.1 event contracts reach FastAPI.
Private object storage remains a possible future backend fallback and is not
part of Phase 5.

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

## 2026-07-15: Phase 6A qualifies extraction and does not add intelligence

The explicit Phase 6A request supersedes the static roadmap's dashboard label.
This phase adds synthetic fixture generation, ground-truth comparison, benchmark
reports, and native-device entry points only. It introduces no deterministic
conversation analytics, semantic AI, scoring, dashboard, or generation feature.

## 2026-07-15: Qualification fixtures are original synthetic archetypes

The suite uses descriptive WhatsApp-, Tinder-, Bumble-, Hinge-, and Instagram
DM-style coverage labels, but its visual system, content, geometry, and assets are
original. No real conversation, product screenshot, protected asset, or exact
competitor layout may enter the repository.

## 2026-07-15: Benchmark diagnostics and exports are content-free

Production extraction exposes only counts and ordered source indices needed for
measurement. JSON and Markdown reports contain fixture IDs and metrics, never
screenshots, transcripts, paths, or hashes. A host reference report cannot
authorize Phase 6B; required physical Android and iOS reports must pass every
documented gate first.
