# Operator user metrics

## What is implemented

PostgreSQL `users` is the single source of truth for registered ConvoCoach
accounts. The protected endpoint below provides aggregate counts without
returning an account list or loading identity and conversation content:

```text
GET /api/v1/admin/user-metrics
Required permission: read:user-metrics
Response schema: user-metrics.v1
```

The response includes total, active, soft-deleted, recent-registration,
effective paid/free, and recent completed-AI-user counts. It never includes an
email, Auth0 subject, display name, conversation, message, screenshot, prompt,
model response, receipt, transaction reference, or per-user row. Responses are
marked `private, no-store`.

Definitions:

- `total_registered_accounts` counts every application account row, including
  an account retained as a minimal deletion tombstone.
- `active_accounts` excludes rows whose account deletion has been requested.
- `new_registered_accounts_7d` and `new_registered_accounts_30d` count account
  creation, even if the account was subsequently deleted.
- `paid_active_accounts` counts distinct, non-deleted users with a current
  server-verified Plus entitlement in `active` or `grace` state.
- `free_active_accounts` is active accounts minus current paid accounts.
- `ai_active_accounts_*` counts distinct, non-deleted users with at least one
  completed server AI usage record in the named window. It is an AI feature
  metric, not general daily/monthly app activity.

No new tracking table, advertising identifier, device fingerprint, or
third-party analytics profile is created.

## Auth0 authorization setup

In the production Auth0 tenant:

1. Open **Applications → APIs → ConvoCoach API Production → Permissions** and
   add `read:user-metrics`.
2. Enable RBAC and **Add Permissions in the Access Token** for that API.
3. Create a least-privilege operator role such as `User metrics viewer`, attach
   only `read:user-metrics`, and assign it only to approved operators.
4. Do not request this permission from the ConvoCoach mobile client. Use a
   separate private operator client or a server-to-server dashboard identity.
5. Keep any client secret in the production secret manager. Never place it in
   mobile configuration, source control, screenshots, shell history, or logs.

The API trusts the permission only after the token's signature, issuer,
audience, issue time, and expiry have passed the production OIDC verifier. A
valid customer token without the permission receives `403`; a missing or
invalid token receives `401`.

## Viewing the count

After obtaining a short-lived operator access token outside shell history:

```bash
read -s CONVOCOACH_OPERATOR_TOKEN
curl --fail-with-body \
  -H "Authorization: Bearer ${CONVOCOACH_OPERATOR_TOKEN}" \
  https://api.example.com/api/v1/admin/user-metrics
unset CONVOCOACH_OPERATOR_TOKEN
```

For a graphical internal dashboard, have the dashboard backend call this same
endpoint and display the aggregates. Do not connect a browser directly to the
database and do not make the endpoint public. PostgreSQL remains authoritative;
a graphing or product-analytics service is only a visualization layer.

## Operational checks

- Alert on unexpected `401`/`403` spikes without logging tokens or subjects.
- Compare counts only at bounded intervals; never export individual account
  records to create this dashboard.
- Review role assignments regularly and revoke access promptly.
- Use database backups and restoration tests for the authoritative user count.
- Treat a count discrepancy as an operations incident; do not compensate by
  adding device tracking.
