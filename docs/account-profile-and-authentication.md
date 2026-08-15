# Account profile and authentication

## Identity mapping

Auth0 remains the credential authority. The backend independently verifies the
access token and maps its immutable `sub` claim to one internal `users.id` UUID.
The `communication_profiles.user_id` primary key is also a cascading foreign key
to that UUID, so Google, Apple, and database-connection sessions for the same
linked Auth0 identity resolve to the same private profile.

The application never stores passwords. Google and Apple authentication, email
and password creation, and password reset all run in Auth0 Universal Login using
authorization code with PKCE. Configure these Auth0 connections for the native
client:

- `google-oauth2` with production Google OAuth credentials;
- `apple` with an Apple Services ID/key and the App Store Sign in with Apple
  capability;
- `Username-Password-Authentication` with email verification, breached-password
  detection, rate limits, and the reset-email template enabled.

Set the public connection names with
`CONVOCOACH_OIDC_GOOGLE_CONNECTION`,
`CONVOCOACH_OIDC_APPLE_CONNECTION`, and
`CONVOCOACH_OIDC_DATABASE_CONNECTION`. The email/password button opens the
protected Auth0 page, where the user can create an account or choose **Forgot
password**. No provider password enters the Flutter process or backend.
The create-account action supplies Auth0's signup screen hint without a
conflicting forced-login prompt. The database connection must be enabled for
the native client before email login or registration can qualify.

## Session continuity

Access, refresh, and ID tokens remain in platform-protected secure storage and
never enter application logs. Cold start resolves the protected session before
navigation: a recoverable account continues to profile setup (which redirects a
completed profile to Home), while an account with no credential continues
through onboarding and sign-in.

Refresh is single-flight because the configured Auth0 tenant rotates refresh
tokens with no reuse overlap. Temporary network, discovery, or provider failures
retain the protected refresh credential and keep the offline shell available;
only an OAuth `invalid_grant` terminal failure clears the session. Release
configuration requires `offline_access`, and interactive cancellation or a
failed account-switch attempt preserves the prior session. The shared system
authentication session provides normal identity-provider SSO continuity without
exposing provider credentials to ConvoCoach.

The tenant's current 15-day idle and 30-day absolute refresh-token lifetimes
still require deliberate reauthentication at those limits. Uninstalling the app
also removes device-protected credentials. These are expected security
boundaries, not silent session loss.

## First-login profile contract

After successful authentication, an incomplete account must finish profile setup
before entering the main app. Name, age 18–120, and at least one hobby are
required. Optional self-described gender, job, what the user wants, relationship
intention, communication tone, message length, emoji preference, and profile
photo can also be supplied and edited later. Lists are bounded to 12 entries and
the photo to 900 KiB. The photo is stored in the encrypted relational database
for the controlled launch, is never public, and is excluded from JSON account
responses and AI prompts. A later private object-storage migration must preserve
the same owner authorization, deletion, and no-store behavior.

Only explicit text fields can tailor AI drafts. They are added after consent to
the provider-neutral bounded context for all configured external providers. The
model is instructed not to infer anything about the other person from this data.

## Operational limitations

Repository support does not create external identity credentials. Apple Sign-In
remains unavailable until the Apple Developer account is eligible and the Auth0
Apple connection is configured. Email/password and reset remain unavailable
until the Auth0 database connection is enabled for the native client. Production
qualification must test sign-up, email verification, login, reset, logout,
account linking, expired tokens, and deletion on physical Android and iPhone
devices.

No store or production-profile build may use reserved example, invalid,
loopback, or localhost API hosts. A real HTTPS API and a private ignored mobile
production configuration are required; checked-in `*.example.json` files are
documentation only. The backend is the durable source of profile fields.
Optional profile-photo download failures no longer hide valid text fields, and
profile writes are blocked when the app cannot first verify a returning user's
server profile. Profile PATCH semantics distinguish omitted fields from an
explicit clear, so users can remove optional self-described fields without
accidentally resetting unrelated choices.
