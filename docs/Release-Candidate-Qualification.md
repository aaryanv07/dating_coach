# Release Candidate Qualification

## Purpose

Phase 14 introduces an offline, deterministic release-candidate manifest and
qualification boundary. It aggregates evidence; it does not run deployment,
sign artifacts, submit stores, approve launch, or reinterpret missing evidence
as success.

The checked-in
`release/phase14/release-candidate-manifest.example.json` is a
schema-valid, content-free example of the current state. It is intentionally
blocked and is not a distributable release candidate.

## Manifest contract

`release-candidate-manifest.v1` contains:

- candidate and application version identifiers;
- a timezone-aware generation timestamp;
- an exact 40-character source revision;
- explicit worktree-clean and source-match booleans;
- production environment and authentication mode;
- production authentication availability;
- AI and mock execution flags;
- explicit Phase 6A.3 status;
- content-free artifact provenance;
- content-free supply-chain component evidence; and
- one result for each closed release gate.

Unknown fields, duplicate artifact/component/gate identifiers, invalid digests,
unbounded identifiers, ambiguous timestamps, and unsupported status values are
rejected.

## Supply-chain evidence

`supply-chain-component-evidence.v1` records only a logical component ID,
SHA-256 digest, and positive byte size. The collector accepts only a
repository-relative regular file beneath the supplied root. It rejects absolute
paths, traversal, symlinks, directories, and empty files.

Evidence JSON never contains source contents or host filesystem paths. The Phase
14 baseline covers:

- backend Python project dependency bounds;
- Flutter package lock;
- iOS Pod lock; and
- Android Gradle wrapper configuration.

Dependency compatibility remains separately proven by `pip check`, Flutter
resolution, Gradle resolution, CocoaPods resolution, and the full build suite.

## Artifact provenance

`release-artifact-provenance.v1` records:

- logical artifact ID and closed platform;
- content type identifier;
- SHA-256 and byte size;
- exact source revision;
- whether the artifact is proven to match that revision;
- a stable build-command ID; and
- explicit signing status.

It contains no host path, signing credential, certificate, provisioning profile,
build log, source contents, or user data. Qualification rejects missing
artifacts, revision mismatch, unverified provenance, and unsigned artifacts.

An unsigned Android AAB or no-codesign iOS application can prove compilation,
but it cannot pass distribution-signing or controlled-launch gates.

## Evaluator

`ReleaseGateEvaluator` is a pure function over the validated manifest. It:

1. requires every gate in the closed catalog;
2. treats missing, failed, blocked, and not-run gates as blocking;
3. independently enforces source cleanliness and revision match;
4. independently enforces production authentication availability;
5. rejects enabled production AI or mock execution;
6. independently enforces Phase 6A.3;
7. independently checks artifact revision and signing fields; and
8. returns sorted, content-free blocking gate IDs and failure codes.

It can return `qualified` only when no blocking gate or invariant remains.
Manual approval cannot override a failed automated invariant.

## CLI

From `backend/`:

```bash
.venv/bin/python -m app.release.cli \
  ../release/phase14/release-candidate-manifest.example.json \
  --expect-status blocked
```

Invalid input returns only `release_manifest_invalid`; it does not echo payload
content or a host path. Operators may omit `--expect-status` to inspect a
validated report. A report is evidence, not deployment authorization.

## Current Phase 14 disposition

The foundation example is blocked because:

- the worktree is not a committed release revision;
- artifact provenance cannot match that revision;
- Android and iOS distribution signing are absent;
- Android and iOS physical-device qualification are absent;
- the production authentication adapter is absent; and
- controlled launch is not authorized.

AI execution and mock execution remain disabled. No schema, migration,
persistence, deployment, or store submission is introduced.
