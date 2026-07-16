# ConvoCoach

ConvoCoach is a privacy-conscious mobile coaching product for healthier dating
communication. This repository currently contains the verified Phase 1
foundation, the Phase 2 mobile experience foundation, the Phase 3
authentication/consent/data slice, the Phase 4 conversation import and review
slice, the Phase 5 provider-neutral extraction engine, and the Phase 6A native
qualification harness. Phase 6A.1 adds the typed conversation-event runtime,
Review Studio corrections, reversible persistence, and a versioned owner-scoped
event API without replacing the legacy message contract. Phase 6A.2 adds
repeatable native readiness detection, schema-validated content-free benchmark
evidence, regression comparison, and expanded original fixtures; physical
Android and iOS evidence remains outstanding. The Phase 6A.3 execution attempt
is truthfully `BLOCKED` before native runs. The Android SDK/ADB toolchain and
CocoaPods are now installed; remaining blockers are full Xcode, both qualifying
physical devices, and a separately authorized Android CargoKit/Gradle 9.1 build
compatibility correction. Phase 6B has not started.

For a Windows primary-development workstation, follow
[docs/windows-development-handoff.md](docs/windows-development-handoff.md).
Windows supports the shared application, backend, tests, Android builds, and
physical Android qualification. The required iOS build, signing, and physical
iPhone qualification remain macOS/Xcode-only.

## Repository layout

```text
apps/mobile/       Flutter Android/iOS application
backend/           FastAPI service and tests
design/tokens/     Platform-neutral design and motion tokens
docs/              Product, architecture, planning, and testing decisions
.github/workflows/ Continuous integration
docker-compose.yml Local PostgreSQL and Redis services
```

## Local backend

```bash
cp .env.example .env
docker compose up -d
python3 -m venv .venv
.venv/bin/python -m pip install -e "backend[dev]"
(cd backend && ../.venv/bin/alembic upgrade head)
.venv/bin/uvicorn app.main:app --app-dir backend --reload --env-file .env
```

PostgreSQL and Redis bind to loopback on ports `5432` and `6379` by default.
Change `POSTGRES_PORT` or `REDIS_PORT` in `.env` when either port is already in
use.

The service exposes:

- `GET /health/live` for liveness
- `GET /health/ready` for configuration readiness
- `GET /docs` for the generated OpenAPI interface
- `/api/v1` identity, preferences, communication profile, consent, conversation,
  reviewed-import confirmation, message, typed-event, and privacy-deletion routes

See [docs/phase-6a1-conversation-event-runtime-foundation.md](docs/phase-6a1-conversation-event-runtime-foundation.md)
for the current event-runtime scope,
[docs/phase-6a-native-extraction-qualification.md](docs/phase-6a-native-extraction-qualification.md)
for the outstanding physical-device gate,
[docs/phase-6a2-native-device-readiness.md](docs/phase-6a2-native-device-readiness.md)
for the runner and evidence workflow,
[docs/phase-6a3-physical-native-qualification.md](docs/phase-6a3-physical-native-qualification.md)
for the current blocked physical-execution report, and
[docs/Conversation-Event-Spec.md](docs/Conversation-Event-Spec.md) for the event
contract. No Phase 6B analytics are included.

## Local mobile app

```bash
cd apps/mobile
flutter pub get
flutter run
```

Mobile flows still use mock, in-memory repositories. Supported Android and iOS
devices use Google ML Kit through a provider-neutral OCR boundary; tests and
unsupported platforms retain deterministic mock OCR. Screenshot bytes remain
temporary and on-device. Review Studio confirmation is required before normalized
conversation events can be saved. The app has no real authentication, backend
transport, AI analysis, or durable device persistence.
