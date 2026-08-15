# Production identity configuration evidence

## Auth0 tenant foundation

- Evidence ID: `phase20.auth0-tenant.jp.20260803`
- Observed at: `2026-08-03T17:28:11+05:30`
- Tenant domain: `convocoach-prod.jp.auth0.com`
- Region: Japan
- Native application: `ConvoCoach Mobile Production`
- Public native client ID: `lXxuFeBQV1ecO6x6BYsrvPs5p5QymNwi`
- API: `ConvoCoach API Production`
- API audience: `convocoach-api`
- Signing algorithm: RS256
- Callback: `com.convocoach.convo-coach:/oauthredirect`
- Logout callback: `com.convocoach.convo-coach:/logout`
- Refresh-token controls: 15-day idle lifetime, 30-day maximum lifetime,
  rotation enabled with zero-second overlap.
- The database connection is disabled for the native application. The Google
  development connection is enabled.

The Auth0 dashboard displayed a successful-save confirmation for the native
application settings. No secret or user record is included in this evidence.

## Android persistent-session qualification

- Evidence ID: `phase20.auth0-android-session.20260815`
- Observed on: `2026-08-15`
- Auth0 saved **Allow Offline Access** for `ConvoCoach API Production`.
- The native application had the **Refresh Token** grant enabled.
- The API maximum access-token lifetime and implicit/hybrid lifetime were both
  set to 3,600 seconds to match the backend's fail-closed verifier policy.
- A Google authorization-code-with-PKCE flow returned through
  `com.convocoach.convo-coach:/oauthredirect` on the physical Xiaomi
  `21091116I`.
- The resulting RS256 token exposed the expected issuer and `convocoach-api`
  audience to a content-free diagnostic check. No token, subject, email, or
  profile content was retained in the evidence.
- The USB-local backend returned `200` for
  `GET /api/v1/communication-profile`. After a full Android force-stop and
  relaunch, the app restored the protected session without showing login and
  the backend returned `200` again.

This qualifies Android callback and local persistent-session behavior for the
observed device. The API was reached through ADB reverse forwarding to a local
backend; this is not production HTTPS deployment, Google production-OAuth
qualification, logout qualification, iOS qualification, or store approval.

## Physical iPhone development launch

- Evidence ID: `phase20.ios-development-launch.20260804`
- Observed on: `2026-08-04`
- Xcode recognized the configured Apple Development identity and generated the
  managed development signing result.
- The Auth0-configured debug build installed after the owner explicitly trusted
  the Developer App certificate. As expected for modern iOS, that debug build
  could not be relaunched after Flutter detached.
- A separately signed Profile build then installed, launched independently, and
  its `Runner.app` process was observed running on the physical iPhone.

This is development launch evidence only. It is not App Store distribution
signing, authentication-flow qualification, native-extraction qualification, or
permission to mark any corresponding production gate as passed.

## Deliberately unqualified

- On 2026-08-08 Xcode showed only `Personal Team 918830770660` with on-device
  testing access, and Keychain contained one Apple Development identity but no
  Apple Distribution identity. App Store Connect reported that the Apple
  Account was not eligible. This is consistent with an Apple Account that has
  not yet completed paid Apple Developer Program enrollment; it cannot create
  an App Store record, distribution profile, or distributable archive.
- Google uses Auth0 development credentials and is not a production Google OIDC
  registration.
- An Apple connection has not been created because the production Apple Services
  ID, team, key ID, and private signing key are not yet available.
- Android login callback and cold-relaunch restoration passed on the observed
  physical device. Logout and iOS authentication flows remain unqualified.
- The Auth0 trial is not evidence of an approved long-term production plan.
- The `read:user-metrics` API permission, least-privilege operator role, and
  separate private operator client still require dashboard configuration and
  an authorization test against the deployed API. The implementation fails
  closed until those steps are complete.
