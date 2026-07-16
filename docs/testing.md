# Testing and Verification

Run backend checks from the repository root unless a working directory is noted.

```bash
ruff format --check backend
ruff check backend
```

Run typing and tests from `backend/`:

```bash
mypy app tests
pytest
alembic upgrade head
alembic check
```

Validate local infrastructure without starting containers:

```bash
docker compose --env-file .env.example config --quiet
```

Run these from `apps/mobile/`:

```bash
flutter pub get
dart format .
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter build bundle --release
```

The backend suite covers liveness/readiness configuration, environment parsing,
design-token validity, token-verifier behavior, schema constraints, user/profile
preferences, append-only consent, conversation ownership, message validation,
conversation deletion, and account-deletion cleanup. API integration tests use
isolated SQLite databases with foreign keys enabled. Alembic upgrade, drift
check, downgrade, and re-upgrade are also verified locally against PostgreSQL;
CI runs upgrade and drift checks against PostgreSQL 16.

The Phase 2 Flutter suite covers onboarding progression, the mandatory privacy
and age gates, mock authentication, bottom navigation, central create sheet,
light/dark tokens, state controllers, reduced motion, 200 percent text scaling,
touch targets, semantics, skeleton behavior, and empty/error/offline states.
The Phase 3 suite adds DTO round trips, mock API/repository contracts, Riverpod
state, profile save/navigation, conversation listing/deletion, and large-text
coverage for the new profile flow.

The Phase 4 backend suite adds confirmation consent, ownership, readiness bounds,
source-disposal validation, normalized message persistence, reopen behavior, and
the absence of screenshot-content columns. The Flutter suite adds screenshot and
paste import, mock OCR, source jumping, editor history, merge, split, speaker
swap, duplicate, move, delete/restore, readiness, normalization, temporary-source
cleanup, mock persistence, list/reopen navigation, semantics, 44-pixel actions,
and 200 percent text scaling in Review Studio.

The Phase 5 Flutter suite uses synthetic images and recognized-text structures
to cover orientation, resizing, contrast, metadata removal, memory limits, ML Kit
mapping, temporary-file cleanup, geometry grouping, speaker ambiguity,
locale-aware timestamps, screenshot ordering, timeline warnings, overlap
deduplication, low-confidence review, canonical normalization, Review Studio
integration, idempotency, bounded retries, cancellation, and screenshot cleanup.
The backend suite validates content-free extraction provenance and rejects raw or
unexpected metadata. Native recognition quality still requires physical-device
benchmarking; host tests do not invoke ML Kit method channels.

Phase 6A adds generated original screenshot fixtures, structured ground truth,
accuracy and correction metrics, confidence calibration, report privacy,
unsupported-format handling, cancellation, cleanup, failure capture, and native
integration entry points. Run its provider-neutral reference benchmark from
`apps/mobile/`:

```bash
dart run tool/generate_phase6a_fixture_catalog.dart
flutter test benchmark/phase6a_reference_benchmark_test.dart --reporter expanded
```

This writes content-free JSON and Markdown summaries under
`build/phase6a-benchmark/reference`. It validates the harness and deterministic
extraction strategies, not native OCR quality. Physical Android and iOS commands
and the gates required before Phase 6B are documented in
`docs/phase-6a-native-extraction-qualification.md`.
CI runs the reference benchmark and release bundle separately from the normal
Flutter test suite; native device runs remain a release qualification activity.

## Phase 6A.2 native-readiness verification

Phase 6A.2 adds a strict v2 benchmark schema, session recording, explicit
PASS/BLOCKED evaluation, device/tool capability detection, native runner
selection, comparison/regression export, cancellation outcome coverage, and
unsupported-platform handling. The synthetic catalog expands from five to seven
original fixtures and now measures typed-event classification for emoji,
reaction, media, deleted, date, encryption, and unread items.

Run from `apps/mobile`:

```bash
flutter test test/phase6a2_native_readiness_test.dart
flutter test benchmark/phase6a_reference_benchmark_test.dart --reporter expanded
dart run tool/run_phase6a2_native.dart
```

The final command exits 2 when prerequisites are absent and writes truthful
content-free readiness evidence under `build/phase6a-readiness`. It must not be
reported as a failed benchmark because no native benchmark was attempted. A
successful physical run writes a schema-validated report under
`build/phase6a-benchmark/<platform>`. Compare repeated runs with
`tool/compare_phase6a_benchmarks.dart` before accepting qualification evidence.
The full procedure and regression thresholds are in
`docs/phase-6a2-native-device-readiness.md`.

## Phase 6A.3 physical qualification attempt

The Phase 6A.3 attempt on 2026-07-15 reran the unchanged common native runner.
It returned expected exit code 2 before benchmark execution: Android lacked the
SDK and a physical device; iOS lacked complete Xcode, CocoaPods, and a physical
device. Zero native runs and zero physical accessibility smoke checks were
performed. This is a prerequisite `BLOCKED` result, not a native benchmark
failure or release qualification.

The provider-neutral seven-fixture benchmark still passed every non-native gate
and its self-comparison reported `NO_REGRESSION`. The wider regression pass also
completed 82 Flutter tests, 43 backend tests, a clean release bundle, isolated
Alembic upgrade/downgrade/re-upgrade/drift verification, and the documented
static privacy and artifact scans. See
`docs/phase-6a3-physical-native-qualification.md` for the exact evidence and
remaining gates. Phase 6B must not start while this result is `BLOCKED`.

Subsequent toolchain setup installed Android Studio 2026.1.2, Android API and
Build Tools 36, ADB/platform tools 37.0.0, NDK 28.2.13676358, CMake 3.22.1, and
CocoaPods 1.17.0. `flutter doctor -v` passes the Android toolchain. An Android
debug-APK preflight fails in the existing `irondash_engine_context` 0.5.5
CargoKit script because Gradle 9.1 removed `Project.exec()`. Flutter's incidental
minimum-SDK rewrite was reverted, and no dependency or production behavior was
changed. Android remains unavailable for qualification until a physical device
is connected and the build compatibility defect receives separate resolution.

## Phase 6A.1 conversation-event verification

The Phase 6A.1 backend suite verifies event and relationship constraints,
ownership-hiding 404s, consent, metadata bounds and prohibited fields, atomic
replacement, relationship references, legacy read-time projection, unchanged
message rows, and deletion cascades. The Flutter suite verifies the complete
event/relationship vocabulary, reaction-versus-emoji classification, target
attachment, date preservation, unknown fallback, event-aware message counting,
deterministic normalization, DTO round trips, and Review Studio corrections.

Migration verification must run upgrade, downgrade to `20260714_0003`, re-upgrade
to head, and `alembic check` against PostgreSQL. The Phase 6A reference benchmark
includes the compact-heart reaction regression and must still pass. Native
Android/iOS OCR and classifier quality are not established by host tests and
remain required physical-device qualification. Analytics-inclusion tests remain
future work because Phase 6B is not implemented.
