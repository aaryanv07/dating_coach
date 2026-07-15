# Phase 3: Authentication, Consent, and Data

## Delivered

- Async SQLAlchemy models and one reversible PostgreSQL Alembic revision
- Provider-neutral bearer-token verification with local/test mock and production
  fail-closed behavior
- Users, preferences, communication profiles, append-only consents
- Owner-scoped conversations, participants, and manual message persistence
- Immediate conversation deletion and account-deletion foundation
- Repository and Pydantic API boundaries with unit/integration tests
- Flutter domain models, DTOs, feature API contracts, mock clients, repositories,
  Riverpod controllers, profile flow, and conversation-list flow

## Explicit exclusions

There is no OCR, screenshot upload, pasted-conversation import, AI/GPT/provider
integration, analysis, scoring, dashboard, reply generation, subscription, or
payment logic. Flutter does not yet call the backend or persist credentials.

## Known limitations

- The production authentication provider adapter is not implemented; production
  fails closed.
- Account deletion records provider cleanup as pending. Provider identity removal,
  audit completion, retries, and final hard deletion belong to hardening work.
- API integration tests use isolated SQLite databases; migrations are separately
  exercised against PostgreSQL.
- Readiness still validates configuration rather than live PostgreSQL/Redis
  connectivity.
