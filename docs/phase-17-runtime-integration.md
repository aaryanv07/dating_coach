# Phase 17 Runtime Integration

Date: 2026-07-27

## Outcome

The Phase 17 runtime description below is historical. Phase 18 supersedes its
default local provider and Keychain setup with Z.ai-hosted GLM-5.2; see
`phase-18-zai-glm-5-2-integration.md`.

Phase 17 implements the missing runtime boundary between the Flutter app, the
owner-scoped FastAPI service, production identity verification, and the Terra
allowance guard. The implementation is usable for local development after the
operator places required secrets in macOS Keychain. It is not a production
launch authorization.

## Implemented

- The mobile conversation repository selects an authenticated HTTP client when
  API and authentication configuration are present.
- A save grants history consent, creates the conversation, confirms only the
  reviewed normalized message sequence, and replaces the versioned event
  sequence. It never uploads screenshot bytes or local paths.
- Mobile OIDC uses Authorization Code with PKCE, the system browser, an exact
  custom redirect, refresh-on-demand, and platform secure storage. No ID token
  is retained and no OpenAI credential enters the app.
- Backend production authentication verifies asymmetric OIDC/JWKS signatures,
  issuer, audience, required timestamps, bounded lifetime, and algorithm policy.
- A reversible migration adds verified subscription entitlements and a
  content-free AI usage ledger.
- The server derives Welcome, Free, or Plus allowance from server state, reserves
  before Terra, completes or releases atomically, and enforces canonical
  idempotency, retry bounds, rate limits, and user/global monthly cost ceilings.
- Terra returns `conversation-coach.v2` with a bounded allowance snapshot. It
  still uses strict structured output, separate external-processing consent,
  `store=False`, and non-persistent results.
- Budget-threshold events contain only aggregate budget kind/percentage. They are
  ready for a production alert sink but do not include a user or content.
- SSD-local setup, Keychain secret configuration, backend launch, and mobile
  device launch are repeatable repository scripts.

## Local run

```bash
./scripts/setup_local_development.zsh
./scripts/configure_local_ai_secrets.zsh
./scripts/run_local_backend.zsh
./scripts/run_local_mobile.zsh --device-id <flutter-device-id>
```

The first script is idempotent. The second prompts only for the OpenAI key and
generates the safety and local bearer secrets automatically, so no secret appears
in shell history or a committed file. The OpenAI key must belong to a billed
project with access to `gpt-5.6-terra`.

Local development uses SQLite created from current SQLAlchemy metadata. Formal
migration checks use PostgreSQL because historical revisions contain
PostgreSQL-specific constraint operations.

## Verification record

- Ruff, strict MyPy, and all 187 backend tests passed.
- Flutter's complete test suite passed with 141 tests.
- Flutter analysis reported no issues.
- PostgreSQL upgraded to `20260727_0005`, reported no pending Alembic operations,
  downgraded to `20260715_0004`, and upgraded again.
- Android debug APK build passed.
- iOS simulator debug build passed.
- A production-configured Flutter bundle and 77.2 MB Android release AAB passed.
- A 76.4 MB signed iOS release build installed on a connected iPhone and passed
  an independent launch/process smoke check after the debug scene manifest was
  corrected to use `UIWindowScene` with `Runner.SceneDelegate` as its delegate.

The user repaired the login-keychain signing partition directly in a hidden
password prompt; the password was not shared or stored. Device console logs
also distinguished the expected iOS limitation that debug builds require
Flutter/Xcode tooling from the independently launchable release build. The
signed installation and startup smoke check do not qualify native extraction:
the required physical OCR fixtures, privacy lifecycle assertions, content-free
report, and Android device suite remain unexecuted. See `docs/testing.md`; no
physical extraction qualification is claimed.

## External launch blockers

The repository cannot create or infer these operator-owned resources:

1. An OpenAI project API key and enabled billing for a live synthetic Terra
   smoke test.
2. A production OIDC tenant/client, registered redirect, issuer, audience, and
   JWKS URL.
3. Apple and Google subscription products, credentials, receipt verification,
   and webhook destinations. Purchase remains disabled until these exist.
4. A deployed HTTPS API, managed PostgreSQL/Redis, secret manager, and alert sink.
5. Distribution signing, store privacy disclosures, incident-response approval,
   live safety evaluation, and the required physical Android/iOS qualification.

Previous coaching outputs are intentionally not persisted. Adding result history
would require an explicit retention purpose, encryption, consent, export, and
deletion design; it is not silently introduced as part of quota enforcement.
