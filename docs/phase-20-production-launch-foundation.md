# Phase 20 — production launch foundation

## Implemented

- Real App Store transaction JWS verification and App Store Server Notifications
  V2 validation using Apple's server library and pinned Apple roots.
- Real Google Play `subscriptionsv2` verification, account binding,
  server acknowledgement, and authenticated Pub/Sub RTDN handling.
- Receipt/token minimization: raw evidence is bounded, never logged, and never
  persisted; durable store references are HMAC-SHA256 values.
- Flutter StoreKit/Play Billing purchase and restore flows. The app completes a
  purchase only after backend verification returns an active/grace entitlement.
- OIDC ID-token retention for provider logout, refresh rotation, Google/Apple
  connection routing, explicit API audience requests, strict production redirect
  and billing configuration.
- Sign in with Apple release entitlement and Xcode capability declaration.
- Google Cloud Terraform for managed TLS, Cloud Run, Cloud SQL PostgreSQL 16,
  HA/TLS Redis, Secret Manager, migration job, workload identity, Play RTDN,
  managed backups, uptime checks, and 5xx alerts.
- Granular production-launch evidence contract, legal/privacy drafts, independent
  AI review protocol, production mobile/backend build scripts, endpoint smoke
  checks, and a cost-authorized isolated backup restore drill.

## Intentionally not self-certified

External account facts are not software changes. The current evidence remains
blocked until the owner supplies a billed cloud project and domain, creates and
accepts Google/Apple/Auth0 agreements, creates store products, grants service
accounts, configures notification URLs, supplies distribution credentials,
executes sandbox/physical-device suites, publishes counsel-approved policies, and
obtains an independent AI safety approval. No test or developer can truthfully
replace those approvals.

## Security and privacy boundaries

- Store secrets and AI credentials are server-side only.
- Google Cloud uses application default credentials; no Play JSON key is required.
- Production images are digest pinned and release scripts require a clean revision.
- Terraform defaults AI execution to disabled; enabling it fails precondition unless
  both external-processing and independent safety approvals are recorded.
- Production readiness checks database connectivity, exact Alembic revision, and
  authenticated TLS Redis before accepting traffic.
- The load balancer terminates managed HTTPS and direct public Cloud Run ingress is
  disabled.

## Verification

The infrastructure syntax passes Terraform initialization and validation with
Google provider 7.42.0 and Random provider 3.9.0. Backend formatting, linting,
strict typing, dependency integrity, and all 230 tests pass. Flutter formatting,
analysis, and all 166 tests pass; the retracted transitive `jni` 1.0.1 was updated
to 1.0.3 with focused billing/privacy regression checks. PostgreSQL upgrade,
drift check, downgrade, re-upgrade, and second drift check pass. Docker Compose
validation, the pinned backend container build, and a containerized readiness
probe against PostgreSQL/Redis pass. Production-configured unsigned Android AAB
and iOS device Release builds pass. The Android bundle was regenerated with
Gradle 8.14.4 after the wrapper security update. These remain build evidence only:
distribution signing, store sandbox execution, and device qualification are not
claimed.
