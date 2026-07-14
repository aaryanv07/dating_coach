# ConvoCoach

ConvoCoach is a privacy-conscious mobile coaching product for healthier dating
communication. This repository currently contains the verified Phase 1
foundation and the Phase 2 mobile experience foundation.

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
.venv/bin/uvicorn app.main:app --app-dir backend --reload --env-file .env
```

PostgreSQL and Redis bind to loopback on ports `5432` and `6379` by default.
Change `POSTGRES_PORT` or `REDIS_PORT` in `.env` when either port is already in
use.

The service exposes:

- `GET /health/live` for liveness
- `GET /health/ready` for configuration readiness
- `GET /docs` for the generated OpenAPI interface

See [docs/phase-0-1-plan.md](docs/phase-0-1-plan.md) for the current scope and
[docs/testing.md](docs/testing.md) for verification commands.

## Local mobile app

```bash
cd apps/mobile
flutter pub get
flutter run
```

Phase 2 uses mock, in-memory state only. It does not perform authentication,
upload conversations, call the backend, or persist personal data.
