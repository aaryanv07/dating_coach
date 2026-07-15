# ConvoCoach

ConvoCoach is a privacy-conscious mobile coaching product for healthier dating
communication. This repository currently contains the verified Phase 1
foundation, the Phase 2 mobile experience foundation, the Phase 3
authentication/consent/data slice, the Phase 4 conversation import and review
slice, and the Phase 5 provider-neutral extraction engine.

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
  reviewed-import confirmation, message, and privacy-deletion routes

See [docs/phase-5-conversation-extraction.md](docs/phase-5-conversation-extraction.md)
for the current scope and [docs/testing.md](docs/testing.md) for verification
commands.

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
conversation data can be saved. The app has no real authentication, backend
transport, AI analysis, or durable device persistence.
