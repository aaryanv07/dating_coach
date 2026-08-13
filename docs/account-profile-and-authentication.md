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
