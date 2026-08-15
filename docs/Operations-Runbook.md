# Operations Runbook

## Purpose

This runbook covers Phase 13 runtime qualification, Phase 14 release evidence,
and a future operator-managed deployment. It does not authorize deployment,
production traffic, live AI, automatic migrations, or store submission.

## Pre-deployment gate

Before creating a production process:

1. Confirm the intended revision and review the complete diff.
2. Run the backend, Flutter, migration, repository, and artifact checks from
   `docs/testing.md`.
3. Supply secrets through the deployment environment or secret manager. Never
   add them to `.env.example`, source control, Dart defines, build logs, or CLI
   history.
4. Configure a non-local PostgreSQL URL using `postgresql+asyncpg`.
5. Configure a non-local TLS Redis URL using `rediss`.
6. Set explicit public API hosts and terminate TLS before the application.
7. Keep both server AI flags false. Do not provide any AI provider credential.
8. Keep the mobile Coach preview and mock mode false for release.
9. Confirm Phase 6A.3 is still treated as a blocking release gate until physical
   evidence exists.
10. Require the Phase 14 evaluator to report `qualified`; the current example
    truthfully reports `blocked`.
11. Configure `read:user-metrics` as a least-privilege Auth0 API permission only
    for the private operator client. Never grant it to the mobile application.

## Required production environment

```text
APP_ENVIRONMENT=production
APP_DEBUG=false
APP_LOG_LEVEL=INFO
OPENAPI_ENABLED=false
OPERATIONAL_CHECKS_ENABLED=true
MAX_REQUEST_BODY_BYTES=1048576
ALLOWED_HOSTS=api.example.com
DATABASE_URL=<secret postgresql+asyncpg URL>
REDIS_URL=<secret rediss URL>
DEVELOPMENT_AUTH_TOKEN=
DEVELOPMENT_AUTH_SUBJECT=
DEVELOPMENT_AUTH_EMAIL=
AUTHENTICATION_VERIFIER_MODE=production_contract
AUTHENTICATION_ISSUER=https://identity.example.com
AUTHENTICATION_AUDIENCE=convocoach-api
AUTHENTICATION_JWKS_URL=https://identity.example.com/keys.json
AUTHENTICATION_ALLOWED_ALGORITHMS=ES256,RS256
AUTHENTICATION_CLOCK_SKEW_SECONDS=60
AUTHENTICATION_MAXIMUM_TOKEN_LIFETIME_SECONDS=3600
AI_COACHING_ENABLED=false
AI_MOCK_EXECUTION_ENABLED=false
```

The example hostname is illustrative. Production startup must fail if an unsafe
or incomplete value is supplied.

## Database migration procedure

Migrations are an explicit operator action and must complete before the new
application starts:

```bash
cd backend
.venv/bin/alembic current
.venv/bin/alembic upgrade head
.venv/bin/alembic check
```

Use the environment-specific virtual environment path where it differs. Review
the downgrade of each revision in a disposable or restored environment before
release. The application startup/readiness code only reads
`alembic_version`; it never calls Alembic or changes schema state.

## User-count operations

The authoritative registered-user count comes from PostgreSQL through the
protected aggregate endpoint `GET /api/v1/admin/user-metrics`. Follow
`docs/operator-user-metrics.md` for Auth0 permission setup, exact metric
definitions, and a token-safe read procedure. Do not query production from the
mobile client, expose an account list, or treat Auth0's dashboard count as the
application source of truth; Auth0 can include identities that never completed
application-user provisioning.

## Service startup and health

Start the process using the environment's managed service runner. Check:

```bash
curl --fail-with-body https://api.example.com/health/live
curl --fail-with-body https://api.example.com/health/ready
```

Liveness should return `ok`. Production readiness must report lifecycle
`ready`, database `ready`, migrations `compatible`, and Redis `ready`.
Do not route traffic when readiness is 503.

Swagger UI and `/openapi.json` must return 404 in production. Verify an approved
host receives HSTS and an unapproved `Host` header is rejected.

## Mobile release qualification

Use content-free build defines:

```bash
cp apps/mobile/config/production.example.json apps/mobile/config/production.json
# Replace every placeholder with registered production values, then:
scripts/build_mobile_release_artifacts.zsh
```

Do not pass an API access token as a Dart define. Android signing properties
belong in a secure CI credential store. An unsigned AAB or no-codesign iOS build
is qualification evidence, not a distributable store artifact.
Replace every identity placeholder with the registered production tenant values.
The build must not be treated as authenticated until Google and Apple sign-in,
refresh, sign-out, revocation, and account deletion pass on physical devices.

## Correlation and incident handling

Use `X-Correlation-ID` to associate a client-visible failure with content-free
request completion records. Operational logs intentionally cannot reconstruct a
conversation, prompt, token, request body, participant, screenshot, raw URL, or
exception message.

If an incident requires private payload inspection, stop and use a separately
approved, consented, time-bounded support process. Do not widen the production
logger or add raw payload logging.

For repeated 413 responses, review the documented request contract before
raising the configured limit. The hard maximum is 10 MiB. Conversation
screenshot bytes must remain in the mobile temporary on-device pipeline and
must not be sent to this backend.

## Rollback

1. Stop routing traffic to the unhealthy revision.
2. Preserve content-free correlation and platform logs.
3. Roll back the application artifact.
4. Downgrade the database only when the reviewed migration rollback plan says it
   is safe and a verified backup is available.
5. Re-run liveness and readiness.
6. Never make startup auto-downgrade or auto-upgrade the database.

If migration compatibility is `incompatible`, treat it as an ordering or
revision incident; do not bypass the check.

## Current stop conditions

- A production deployment enables the Terra provider before the Phase 16
  privacy, identity, evaluation, budget, physical-device, and release gates are
  complete.
- Either production AI flag becomes true.
- A mobile release embeds an access token or enables mock/preview behavior.
- Production authentication is unavailable or does not satisfy the exact
  verifier policy.
- A release manifest is invalid, blocked, incomplete, or does not match the
  exact clean source revision and signed artifacts.
- Startup or readiness applies a migration.
- Logs or errors contain private request material.
- Phase 6A.3 is represented as passed without physical-device evidence.

Any stop condition blocks release and requires a separate corrective change and
review.
