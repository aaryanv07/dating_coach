# Google Play release readiness

## Implemented repository controls

- Android package `com.convocoach.convo_coach`, minimum SDK 24, and current
  Flutter target SDK (verified as API 36 on the qualified physical build).
- Release signing accepts secrets from process environment or private Gradle
  properties and rejects partial configuration.
- `scripts/create_android_upload_key.zsh` creates a non-replaceable RSA-4096
  upload key under the internal macOS application-support directory, stores both
  passwords in Keychain, and never writes secrets to the repository or external
  unencrypted SSD.
- `scripts/build_google_play_bundle.zsh` requires a clean revision, a real ignored
  production configuration, Google identity and product IDs, HTTPS API, no
  embedded token, all Flutter checks, the Phase 6A benchmark, and verification
  that the AAB signer matches the protected upload key before copying an AAB and
  SHA-256 digest to `release/`.
- Android startup validation requires only Android identity and billing facts;
  Apple-only connection and product facts remain mandatory for iOS releases.
- Live AI output includes in-app reporting. The server persists only owner ID,
  conversation ID, opaque response ID, a bounded safety category, status, and
  timestamps. The report is exported and cascades on deletion; message text,
  screenshots, prompts, generated output, and free-form notes are excluded.
- Original Play icon and feature-graphic assets plus reviewed listing copy and a
  Data Safety engineering workbook are under `store/google-play/`.

## External blockers — do not mark production ready yet

The repository cannot create or truthfully attest these account-owned facts:

1. A production HTTPS API, PostgreSQL, Redis, migrations, TLS, backups, alerts,
   support mailbox, and monitored operational ownership.
2. Approved and published privacy/terms pages with a functional external account
   deletion URL. The legal drafts still contain entity, address, contact,
   jurisdiction, processor, retention, and effective-date placeholders.
3. Active Google Play monthly/yearly subscription products, Play Developer API
   service-account access, RTDN, backend receipt verification credentials, and
   successful license-tester lifecycle evidence.
4. Google production OAuth credentials at Auth0 and physical-device sign-in,
   refresh, logout, revocation, export, and account deletion evidence.
5. Play Console app creation, Play App Signing enrollment, content rating, Data
   Safety, ads declaration, target-audience/18+ configuration, app-access review
   instructions, store-listing review, and policy approval.
6. If the developer account is a newly created personal account, at least 12
   opted-in closed-test users continuously enrolled for 14 days before production
   access can be requested.
7. A signed clean-revision AAB uploaded to internal/closed testing, automated Play
   pre-review passed, crash/ANR monitoring configured, and staged rollout owned by
   an authorized launch operator.

## Build sequence after external facts exist

1. Copy `apps/mobile/config/production.google-play.example.json` to the ignored
   `production.google-play.json` and replace the API and product placeholders.
2. Run `scripts/create_android_upload_key.zsh` once, then make an encrypted
   offline backup of the keystore and verify restore. Never regenerate or lose it.
3. Commit/review all source changes so the tree is clean.
4. Run `scripts/build_google_play_bundle.zsh`.
5. Upload `release/google-play/convocoach-google-play.aab` to Play internal
   testing, complete policy declarations and license-test all critical flows.
6. Promote to closed testing, satisfy any account testing requirement, then use a
   small staged production rollout only after all external blockers are evidenced.
