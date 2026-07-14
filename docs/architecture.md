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
server-side policy enforcement and, in later phases, durable application data.
Design tokens are platform-neutral JSON so Flutter and any future web or design
tool integration can consume the same semantic names.

## Backend shape

The backend uses an application factory so tests can supply isolated settings.
Routes live under `app/api/routes`, environment parsing under `app/core`, and
future integrations should be placed behind service or repository boundaries.

Current endpoints:

| Endpoint | Meaning | Dependency behavior |
| --- | --- | --- |
| `GET /health/live` | The API process can serve HTTP | No external check |
| `GET /health/ready` | Required service URLs are configured | No live probe |

Configuration readiness is deliberately narrower than operational readiness.
Live PostgreSQL and Redis probes must be added when clients and lifecycle
management are introduced. Until then, neither the API nor documentation may
claim that those dependencies are reachable.

## Local infrastructure

Docker Compose provides PostgreSQL 16 and Redis 7 with persistent named volumes,
container health checks, and loopback-only host ports by default. The API runs on
the host during this phase. No application schema or Redis data contract exists.

## Initial decisions

1. Use a monorepo so product rules, API contracts, tokens, and mobile code change
   together during early development.
2. Use semantic design tokens rather than feature-specific color constants.
3. Use standard-library environment parsing to keep the service foundation small.
4. Keep liveness independent from dependencies and make readiness fail closed when
   required URLs are absent.
5. Defer database and Redis client libraries until code actually uses them.
6. Use Riverpod for explicit local application state and GoRouter for navigation
   state, while keeping Phase 2 free of persistence and backend integration.
7. Generate only Android and iOS platform shells because the product is mobile
   only.
8. Keep onboarding, authentication shell, feature shell, and reusable core UI in
   feature-oriented modules rather than a single widget file.

See `docs/mobile-architecture.md` for the Phase 2 mobile structure.
