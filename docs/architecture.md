# Architecture

## Monorepo boundaries

```text
ConvoCoach
|-- apps/mobile       Flutter client boundary
|-- backend           FastAPI service
|-- design/tokens     Shared semantic design source
|-- docs              Plans, decisions, and operating guidance
|-- docker-compose.yml
`-- .github/workflows
```

The mobile client owns presentation and device interaction. The API owns
server-side policy enforcement and durable application data.
Design tokens are platform-neutral JSON so Flutter and any future web or design
tool integration can consume the same semantic names.

## Backend shape

The backend uses an application factory so tests can inject session factories
and token verifiers. Routes live under `app/api/routes`, SQLAlchemy models under
`app/db`, owner-scoped queries under `app/repositories`, and API contracts under
`app/schemas`. Alembic is the only supported production schema-change path.

Current endpoints:

| Endpoint | Meaning | Dependency behavior |
| --- | --- | --- |
| `GET /health/live` | The API process can serve HTTP | No external check |
| `GET /health/ready` | Required service URLs are configured | No live probe |

Configuration readiness remains narrower than operational readiness. A live
PostgreSQL/Redis probe is still required before production deployment; migration
verification is separate and runs against PostgreSQL.

## Local infrastructure

Docker Compose provides PostgreSQL 16 and Redis 7 with persistent named volumes,
container health checks, and loopback-only host ports by default. The API runs on
the host. PostgreSQL stores identity, consent, profile, normalized conversations,
message review metadata, and content-free source-disposal metadata. Screenshot
bytes remain a temporary mobile concern. Redis still has no application data
contract.

## Initial decisions

1. Use a monorepo so product rules, API contracts, tokens, and mobile code change
   together during early development.
2. Use semantic design tokens rather than feature-specific color constants.
3. Use standard-library environment parsing to keep the service foundation small.
4. Keep liveness independent from dependencies and make readiness fail closed when
   required URLs are absent.
5. Use SQLAlchemy's async session boundary and PostgreSQL migrations; keep Redis
   deferred until a later phase owns jobs or caching.
6. Use Riverpod for explicit local application state and GoRouter for navigation
   state, while keeping Phase 2 free of persistence and backend integration.
7. Generate only Android and iOS platform shells because the product is mobile
   only.
8. Keep onboarding, authentication shell, feature shell, and reusable core UI in
   feature-oriented modules rather than a single widget file.

9. Resolve the user only from verified token claims and return 404 for resources
   that are absent or owned by another user.
10. Delete conversation records immediately. Account deletion removes sensitive
    child data, redacts profile identity, blocks re-entry, and records pending
    external identity-provider cleanup.
11. Keep OCR, review, normalization, persistence, and any future analysis as
    separate stages. Phase 4 cannot invoke analysis before user confirmation.
12. Treat readiness as deterministic data quality and require active history
    consent before confirmed imports are persisted.
13. Keep Google ML Kit behind `TextRecognitionProvider`; recognized structure is
    provider output, while bubble grouping, geometry, timestamps, ordering, and
    overlap detection are separate deterministic strategies.
14. Keep extraction idempotency in the mobile session and persist only
    content-free provider/pipeline versions, never screenshot fingerprints.

See `docs/mobile-architecture.md`, `docs/backend-architecture.md`, and
`docs/database-schema.md` for the current component boundaries.
