# Production launch runbook

## Current status

The repository contains deployable production boundaries, not production account
ownership or approval. `release/phase20/production-launch-evidence.current.json`
truthfully records every unexecuted external gate as `false`. Never change a field
to `true` without a durable content-free evidence ID.

## 1. Identity tenant

Use one production OIDC broker tenant (the current mobile connection parameters
are compatible with Auth0) and create a native application plus API audience
`convocoach-api`. Register exactly:

- callback: `com.convocoach.convo-coach:/oauthredirect`
- logout callback: `com.convocoach.convo-coach:/logout`
- Google connection name: `google-oauth2`
- Apple connection name: `apple`

The production tenant foundation is recorded in
`Production-Identity-Configuration-Evidence.md`. The mobile client must send
`CONVOCOACH_OIDC_AUDIENCE=convocoach-api` on authorization requests so Auth0
issues an access token for the backend rather than only an identity token.

Create Google Web OAuth credentials for the broker's exact HTTPS callback. In the
Apple Developer account, enable Sign in with Apple for
`com.convocoach.convoCoach`, create the required Services ID/key for the broker,
and register its exact HTTPS return URL. Enable refresh-token rotation, breached
password/attack protection where applicable, short access tokens, and exact API
audience/JWKS validation. Test sign-in, refresh, logout, cancellation, revoked
consent, and account deletion on both physical platforms.

## 2. Store billing

Create one subscription group/base plan with monthly and yearly Plus products:

- `com.convocoach.plus.monthly`
- `com.convocoach.plus.yearly`

The localized price shown by each store is authoritative; the app never hard-codes
a checkout price. Configure App Store Server Notifications V2 at
`https://<api-domain>/api/v1/subscription/notifications/apple`. In Google Play,
grant the Terraform output `play_api_service_account` app-level financial/order
permissions required to verify and acknowledge purchases. Set the RTDN topic to
the Terraform `play_rtdn_topic` output. Complete license-tester/TestFlight sandbox
purchase, renewal, restore, cancellation, grace, expiry, and refund/revocation
tests. Confirm that a failed backend verification never completes or grants a
purchase.

## 3. Cloud foundation

1. Create a dedicated billed Google Cloud project and a versioned/encrypted remote
   Terraform state bucket with restricted access and retention.
2. Copy `infra/gcp/terraform.tfvars.example` to the ignored
   `production.auto.tfvars` and replace every value.
3. Build a reviewed clean revision with `scripts/build_production_backend.zsh` and
   use the returned digest in the Terraform variables.
4. Initialize/apply the foundation, then use
   `scripts/configure_gcp_production_secrets.zsh` to add the OpenRouter key without
   printing it. Apply the full plan.
5. Point the API domain A record to `api_load_balancer_ip` and wait for the managed
   certificate to become active.
6. Execute the migration job, then run `scripts/verify_production_endpoint.zsh`.

Terraform provisions regional PostgreSQL 16 with SSD, point-in-time recovery and
14 backups; HA Redis with AUTH and transport encryption; Cloud Run with workload
identity and bounded scaling; Secret Manager; authenticated Play RTDN; managed TLS;
and uptime/5xx alert policies. The first apply incurs cloud cost and therefore
requires the account owner to approve the project and billing scope.

## 4. Backup restoration and alerts

Restore a current Cloud SQL backup into an isolated temporary instance. Apply the
same migration version, verify only schema counts and synthetic records, then
destroy the temporary instance under change control. Record RPO/RTO, backup ID,
source/target regions, revision, outcome, and operator—never rows or user content.

Trigger the uptime and 5xx alerts in a staging project, confirm delivery to the
monitored incident mailbox and acknowledgement by the on-call owner, then close the
test incident. A configured notification channel without a delivered test does not
pass.

## 5. Distribution and devices

Use a paid Apple Developer organization/team and Play App Signing. Keep private
keys in managed signing storage, not the repository. Produce a signed iOS archive
and signed Android AAB from the exact clean revision. Complete Phase 6A.3 plus
authentication, store purchase, privacy, deletion/export, reduced-motion, and
crash-free launch tests on representative physical iPhone and Android devices.

## 6. Governance and controlled launch

Replace all placeholders in the privacy and terms drafts. Obtain approved processor
terms/DPA, jurisdictional legal/privacy review, store metadata review, and the
independent AI safety report. Publish the approved policy URLs in both stores and
the app. Only then may an authorized launch owner approve a staged rollout. Start
with a small percentage, monitor crashes, latency, AI spend, safety errors,
subscription verification, deletion SLAs, and support escalation before expanding.

## Evaluation

From `backend/`, run:

```text
python -m app.release.production_launch_cli \
  ../release/phase20/production-launch-evidence.current.json
```

Exit `0` means every production fact is evidenced. Exit `1` means launch is
blocked. Exit `2` means the evidence file is invalid.
