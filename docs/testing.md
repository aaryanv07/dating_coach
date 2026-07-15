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
