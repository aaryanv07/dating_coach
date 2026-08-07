# Controlled Launch Runbook

## Current status

Controlled launch is **not authorized**. This runbook records the future
operator sequence and stop conditions; it does not deploy infrastructure, sign
an artifact, submit an app, create credentials, enable AI, or send traffic.

## Required entry conditions

Do not begin launch preparation until all of the following exist:

1. a reviewed, clean, committed source revision;
2. a manifest whose source and artifacts match that exact revision;
3. passing backend, Flutter, database, repository, and privacy/security gates;
4. approved dependency and artifact provenance evidence;
5. an authorized production authentication adapter and mobile flow;
6. passing Android and iOS distribution signing;
7. passing Phase 6A.3 Android and iOS physical-device reports;
8. tested data export, deletion, backup, restore, incident, and rollback paths;
9. legal/privacy/store review for the intended jurisdictions; and
10. named controlled-launch approval after every automated gate passes.

No manual approval may replace items 1–9.

## Qualification sequence

1. Freeze the candidate revision and stop unrelated changes.
2. Recreate the environment from reviewed dependency locks.
3. Run every command in `docs/testing.md`.
4. Build production-configured mobile artifacts with mock, preview, and AI
   execution disabled.
5. Sign through the approved credential system without exposing secrets to
   source, logs, command history, manifests, or artifacts outside the release
   system.
6. Run the physical Android and iOS Phase 6A.3 suites.
7. Collect only content-free dependency, artifact, and gate evidence.
8. Validate the manifest and require an evaluator result of `qualified`.
9. Perform human privacy, security, accessibility, product-safety, and store
   review.
10. Record explicit launch authorization, audience size, monitoring ownership,
    rollback owner, and expiry.

Phase 14 completes none of these launch actions.

## Production authentication stop gate

Stop if the production adapter, issuer, audience, key rotation, redirect
binding, nonce/state validation, secure mobile credential storage, revocation,
account deletion, provider outage behavior, or audit evidence is incomplete.
The current `UnavailableProductionAuthenticationVerifier` always triggers this
stop gate.

## AI stop gate

Keep `AI_COACHING_ENABLED=false`,
`AI_MOCK_EXECUTION_ENABLED=false`, and the mobile Coach preview disabled.
Stop if an external AI SDK, provider credential, endpoint, outbound request,
prompt execution, generated coaching content, or production provider
registration appears. Phase 14 does not authorize any of them.

## Privacy and safety stop gates

Stop if:

- logs, manifests, reports, or diagnostics contain credentials, message bodies,
  prompts, screenshots, OCR text, private paths, emails, or auth subjects;
- screenshot bytes leave the temporary on-device import boundary;
- analysis can run before corrected normalized events are confirmed;
- owner scoping, active consent, deletion, or export behavior regresses;
- a product flow enables manipulation, deception, stalking, harassment,
  coercion, boundary evasion, or romantic interactions involving minors; or
- generated uncertainty and user-agency protections are weakened.

## Rollback readiness

Before any future limited traffic:

- identify the previous application artifact and compatible database revision;
- verify backup restoration in an isolated environment;
- define traffic disablement and mobile release halt procedures;
- verify liveness/readiness and authentication outage behavior;
- keep migrations as explicit operator actions; and
- ensure rollback does not re-enable mock or AI execution.

If rollback requires a database downgrade, use only a reviewed revision-specific
plan with a verified backup. Runtime startup must never migrate automatically.

## Launch monitoring

Future monitoring may use content-free availability, latency, status, dependency
readiness, and correlation data. It must not capture conversation content,
tokens, claims, prompts, screenshots, raw URLs, or exception payloads. A
separate authorized support process is required for any private-data inspection.

## Current blocking summary

- Phase 6A.3 Android: blocked.
- Phase 6A.3 iOS: blocked.
- Production authentication adapter: absent.
- Android distribution signing: absent.
- iOS distribution signing/provisioning: absent.
- Clean committed Phase 14 provenance: absent by instruction.
- Controlled launch approval: not requested or granted.
