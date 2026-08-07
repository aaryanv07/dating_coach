# Release Gate Specification

## Status model

Each `release-gate-evidence.v1` record uses one status:

- `pass`: the named gate has current evidence and no failure code;
- `fail`: the check ran and violated a requirement;
- `blocked`: a mandatory prerequisite or authorization is unavailable; or
- `not_run`: no current execution evidence exists.

Every non-passing record requires at least one content-free failure code. Passing
records cannot carry failure codes. Gate and evidence IDs are closed, bounded
identifiers rather than free-form descriptions.

## Mandatory gate catalog

| Gate | Passing evidence |
| --- | --- |
| `backend_quality` | Ruff format/lint, strict MyPy, Pytest, and `pip check` pass |
| `flutter_quality` | dependency resolution, format, analyze, tests, and benchmark pass |
| `database_migrations` | upgrade, check, downgrade, re-upgrade, and check pass |
| `repository_validation` | Docker, OpenAPI, JSON/YAML, and diff validation pass |
| `privacy_security_scans` | provider, network, secret, content, and artifact scans pass |
| `supply_chain_evidence` | required allowlisted dependency inputs have digest evidence |
| `artifact_provenance` | every artifact is bound to the exact clean source revision |
| `android_release_build` | production-configured release AAB builds |
| `ios_release_build` | production-configured iOS release target builds |
| `android_release_signing` | distributable artifact has approved release signing |
| `ios_release_signing` | distributable archive has approved signing/provisioning |
| `android_physical_qualification` | required Phase 6A.3 Android report passes |
| `ios_physical_qualification` | required Phase 6A.3 iOS report passes |
| `production_authentication` | authorized production verifier and mobile flow pass |
| `production_ai_disabled` | server and mobile production AI execution is disabled |
| `mock_execution_disabled` | server/mobile mock and preview execution is disabled |
| `source_revision_clean` | reviewed clean worktree exactly matches the revision |
| `controlled_launch_approval` | named operator approval exists after all other gates |

The v1 catalog above remains available only to evaluate historical Phase 14
manifests. New candidates use `release-candidate-manifest.v2`, replace
`production_ai_disabled` with `production_ai_qualified`, and add these mandatory
gates:

| V2 gate | Passing evidence |
| --- | --- |
| `production_ai_qualified` | explicitly configured Z.ai GLM-5.2 or OpenRouter tiered provider, usage enforcement, external-processing approval, and live safety evaluation all pass |
| `production_deployment` | deployed HTTPS API and managed dependencies pass readiness and rollback checks |
| `store_billing_qualified` | Apple/Google products, verification, notifications, restore, and sandbox purchase paths pass |
| `backup_restore_qualified` | an isolated backup restoration exercise passes |
| `observability_alerting_qualified` | content-free monitoring and actionable alert delivery pass |
| `legal_privacy_review` | authorized legal, privacy, processor, and store review passes |

## Invariants

The evaluator enforces several invariants even if a manifest incorrectly marks
the corresponding record as passed:

- `phase6a3_status` must be `pass`;
- source must be clean and match the revision;
- production authentication must be available;
- v1 production AI and mock execution must both be false;
- at least one artifact and one supply-chain input must exist;
- every artifact revision must equal the candidate revision;
- every artifact must match that revision; and
- every artifact must be distribution-signed.

The v2 evaluator instead permits production AI only when its fixed provider,
usage controls, independent processing approval, and safety evaluation are all
affirmatively evidenced. It independently rechecks every added structured gate,
so a passing gate record cannot hide missing deployment, store, restore,
monitoring, or legal prerequisites.

This duplication is intentional defense in depth. A self-asserted gate record
cannot override the candidate’s structured facts.

## Phase 6A.3

Phase 6A.3 can pass only when the documented Android and iOS physical-device
suites produce schema-valid, content-free reports and every required
quality/performance gate passes. Simulator, emulator, host, build-only, unsigned,
or no-codesign results cannot satisfy these gates.

Phase 14 preserves the current Phase 6A.3 state as `blocked`.

## Current status

Backend, Flutter, database, repository, security/privacy, supply-chain input,
and unsigned build evidence may pass during Phase 14 verification. The overall
candidate still cannot qualify while production authentication, distribution
signing, physical-device qualification, clean committed provenance, and
controlled-launch approval are absent.

## Change control

Adding, removing, renaming, or weakening a gate changes a versioned release
contract and requires explicit authorization, tests, documentation, and review.
No runtime API or mobile client may set release-gate status.

## Granular production launch evidence

The v2 release-candidate contract remains the artifact-level gate. Phase 20 adds
`production-launch-evidence.v1` as a stricter operational checklist covering each
Google/Apple OIDC registration, each store and notification path, deployed
dependencies, restore/alert drills, distribution signing and physical devices,
published legal documents, processor review, independent AI safety approval, and
controlled-launch ownership. A generic v2 `store_billing_available=true` cannot
replace these individual facts. Evaluate it with
`python -m app.release.production_launch_cli` as described in the production
launch runbook.
