# Phase 19: Production Hardening

Date: 2026-07-29

## Outcome

Phase 19 hardens the repository for a future controlled production launch. It
does not claim that operator-owned infrastructure, store products, legal review,
or physical-device gates exist. The v2 release evaluator keeps each missing
prerequisite explicit and fail closed.

Repository-controlled additions include:

- a lifecycle privacy shield that covers conversation UI before operating-system
  app-switcher snapshots;
- disabled Android cloud backup/device transfer and disabled release cleartext
  traffic, while preserving the debug-only local HTTP override;
- an iOS privacy manifest declaring no tracking and the linked data used only
  for application functionality;
- two independent production AI attestations for external processing review and
  provider-independent safety evaluation;
- a v2 release-candidate contract that can qualify the fixed Z.ai GLM-5.2 path
  only with usage enforcement and affirmative review evidence;
- additional non-bypassable deployment, billing, backup/restore, monitoring,
  and legal/privacy release gates;
- separate hash-locked Python runtime and development/test dependency sets; and
- a non-root backend container with a pinned base-image digest, a liveness check,
  and no embedded secrets; and
- weekly dependency-update monitoring for Python, Dart, Gradle, GitHub Actions,
  and the backend container base.

The subsequent launch-experience pass adds one original global Stats dashboard,
protected outcome/reflection storage, reduced-motion premium presentation, and
broker-specific Google/Apple OIDC entry points. These repository changes do not
complete the external launch gates below.

## Security and privacy boundaries

Production GLM execution remains impossible unless the server receives both
`AI_EXTERNAL_PROCESSING_APPROVED=true` and
`AI_SAFETY_EVALUATION_APPROVED=true`. These flags are evidence references, not
self-approval: the operator must retain the underlying processor/privacy and
safety evaluation records. Mock execution remains forbidden.

The production container installs only hash-verified runtime dependencies,
runs as UID/GID 10001, starts no migration automatically, and expects all
credentials from the hosting secret manager. Forwarded proxy headers are not
globally trusted by the image.

## Remaining controlled-launch gates

The application is not yet a distributable production release. The following
cannot be truthfully completed from repository code alone:

- deployed HTTPS API, managed PostgreSQL/Redis, secret manager, domain, alerting,
  backup and isolated restore evidence;
- configured OIDC issuer/client/redirect and end-to-end identity qualification;
- Apple App Store and Google Play products, distribution credentials, receipt
  verification, server notifications, sandbox purchases, and store approval;
- Android distribution signing and a connected physical Android qualification
  device;
- passing Android and iOS Phase 6A.3 extraction/accessibility reports;
- processor/legal/privacy/store-jurisdiction review and named launch approval;
  and
- a clean reviewed commit whose artifacts match its exact revision.

No example configuration or manifest may be represented as proof of those
external facts.

## Local verification record

The following repository-controlled checks completed on 2026-07-29:

- backend formatting, linting, and static typing passed;
- all 210 backend tests passed both in the existing development environment and
  in a clean Python 3.13 environment installed exclusively from
  `requirements-dev.lock` with hash verification;
- `pip check` passed for the hash-locked environment;
- Flutter formatting and static analysis passed;
- all 147 Flutter tests passed;
- the production-configured Flutter release bundle compiled;
- the unsigned Android release AAB compiled and includes shrinker mapping;
- the unsigned iOS device release compiled and packages the application privacy
  manifest; and
- Docker Compose configuration validation passed.

The release artifacts are intentionally unsigned and were built with invalid
placeholder production service URLs. They demonstrate release compilation, not
deployability. Their current content-free identifiers are:

- Android AAB SHA-256
  `d2a2e994fb84afd89c6ee9719d93c7d6b8d6bc319a6e9d2a5e5734c3e04fde09`;
- iOS Runner executable SHA-256
  `2451478dc83c6f7326877593aaad56b1e62491756477b6defe3ce74f65121b60`.

The provider-neutral Phase 6A reference suite completed every synthetic fixture
with perfect extraction, event, speaker, timestamp, ordering, warning, review,
and cleanup results. It remains blocked because measured p95 latency was
27,410 ms against the required 2,500 ms and a host run cannot satisfy the
native-device gate. The performance threshold was not weakened.

The backend container also built successfully from its pinned Python base-image
digest. A staging-mode runtime probe confirmed UID/GID 10001, PostgreSQL
connectivity, exact migration compatibility, Redis connectivity, lifecycle
readiness, and the health contract. A current PostgreSQL
upgrade/check/downgrade/re-upgrade/check cycle passed against PostgreSQL 16.
These local checks do not replace a successful external CI run or evidence from
the eventual managed production environment.

The connected iPhone 13 Pro Max passes tool and device readiness detection. The
Apple Development key's Apple-tool partition access was repaired after explicit
owner approval. A signed Profile build installed, launched independently from
the Home Screen, remained alive after Flutter tooling detached, and received a
successful conversation-list response from the local backend.

The physical iOS benchmark then completed all seven original synthetic fixtures
with no failures or cancellations, 100% cleanup, a passing cancellation probe,
1,191 ms p95 latency, and native-device evidence. The iOS physical gate remains
blocked because event classification was 94.76% against the required 95% and
the minimum fixture message extraction result was 80% against 90%. A bounded
cropped-line grouping correction and regression test were added; its physical
rerun was interrupted by wireless VM-service discovery and is not represented
as passing evidence.

Release signing retains `NSFileProtectionComplete`. The synthetic-device
Debug/Profile configuration intentionally omits that distribution entitlement
because an Apple Personal Team provisioning profile cannot authorize it; this
exception is limited to local qualification builds and is not acceptable for a
store candidate.
