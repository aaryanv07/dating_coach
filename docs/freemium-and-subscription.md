# Freemium and Subscription Requirements

## Approved commercial model

ELLIS launches with a useful permanent Free plan and one paid plan. It has
no weekly subscription and makes no unlimited-AI claim.

### Thirty-day welcome allowance

The welcome allowance requires no payment method and never converts a user to a
paid subscription automatically.

- five conversation analyses during the first 30 days;
- 25 reply-generation actions during the first 30 days;
- five first-message generations during the first 30 days; and
- one progress insight per week during the first 30 days.

When it ends, the account moves to the permanent Free plan. The transition does
not remove saved data or previously generated results.

### Free

- Price: INR 0.
- Two conversation analyses each month.
- Ten reply-generation actions each month.
- Three first-message generations each month.
- One progress insight each month.
- Unlimited access to existing saved results and connection workspaces, subject
  to the user's explicit retention choices.

### ELLIS Plus

- Monthly price: INR 999.
- Annual price: INR 8,999, approximately INR 750 per month.
- Twelve conversation analyses each billing month.
- Eighty reply-generation actions each billing month.
- Ten first-message generations each billing month.
- One progress insight each week.
- Unlimited access to existing saved results and connection workspaces, subject
  to the user's explicit retention choices.

Annual and monthly prices are localized storefront prices. A live purchase
screen must load authoritative price and renewal copy from Apple or Google. The
checked-in mobile values are preview copy and cannot be trusted for a purchase.

## Usage-counting contract

The future backend is the entitlement and usage source of truth. The mobile
application must never grant an entitlement or decrement a quota locally.

- A conversation analysis is consumed only after the backend accepts a new,
  idempotent analysis job for a corrected and explicitly confirmed conversation.
- Each new connection may have its own dashboard. Updating an existing
  connection with confirmed messages consumes an analysis only when a new job is
  accepted.
- Viewing a stored dashboard or analysis snapshot does not consume usage.
- A provider failure, schema-validation failure, cancelled job, or idempotent
  retry does not consume usage.
- A reply-generation action returns up to three user-reviewable drafts. Copying,
  editing, or viewing those drafts does not consume another action. A
  regeneration that starts a new provider request consumes one action.
- A first-message action returns the approved structured opener set. Reviewing
  or editing it does not consume another action.
- Allowances reset on the server-owned monthly billing boundary and do not roll
  over. Weekly progress eligibility uses a server-owned seven-day boundary.
- Quota reservations must be atomic and released when a job fails before a
  billable provider result exists.

The eventual API must return stable allowance identifiers, limits, consumption,
remaining usage, reset timestamps, plan status, and a server-generated version.
It must not return or accept a client-calculated entitlement.

## Non-paywalled protections

The following remain available on every plan after an allowance is exhausted:

- safety warnings and boundary guidance;
- privacy controls;
- viewing existing results;
- data export and deletion;
- account deletion; and
- consent and subscription-management information.

The product must not use shame, fake urgency, hidden renewal terms, obstructive
cancellation, or a forced payment method for the welcome allowance. Before live
purchase is authorized, the plan screen must state the billing period, renewal
behavior, current allowance, reset date, and cancellation path.

## Privacy-safe operations

Usage and billing records may contain user ID, allowance type, idempotency key,
job ID, model identifier, content-free token counts, estimated cost, storefront,
transaction status, and timestamps. They must never contain screenshots,
conversation text, prompts, generated drafts, profile content, or provider
payloads.

The internal cost dashboard aggregates content-free usage only. It tracks model
cost per completed action, trial-cohort cost, paid-plan cost, cache utilization,
provider failures, and allowance exhaustion without exposing private content.

## Launch cost guardrail

The planning ceiling is approximately INR 48 per fully used ongoing Free user
per month, INR 118 for a fully used welcome allowance, and INR 305 per fully used
Plus user per month for model usage. These are planning estimates, not customer
prices or guarantees. They must be replaced with measured content-free usage
before purchases are enabled, with alerts for material variance.

The current OpenRouter defaults use `openai/gpt-4o-mini` for welcome/Free and
`openai/gpt-5.6-terra` for verified Plus. OpenRouter's model API listed USD 0.15
input/0.60 output per million tokens for GPT-4o mini and USD 1.00 input/6.00
output for Terra on 2026-08-06. These mutable provider prices do not validate the
INR ceilings. Before enabling purchases, measure content-free input/output token
distributions with synthetic or properly consented traffic, recheck current
prices, apply exchange rates and taxes, include retries and safety/evaluation
overhead, and recalculate every plan's worst-case and expected margin. No
unlimited-usage promise is permitted. See `openrouter-tiered-ai-routing.md`.

## Phase 15 boundary

Phase 15 implements immutable server catalog contracts, a pure content-free
allowance evaluator, and a non-purchasing mobile plan preview. The catalog is
closed and all plan definitions keep `purchase_enabled` false.

Phase 15 deliberately adds no API route, database migration, usage ledger,
reservation, store SDK, receipt, webhook, purchase, restore, renewal,
cancellation, refund, entitlement persistence, provider execution, or live
quota enforcement.

Live billing requires a separately authorized implementation:

1. Apple and Google product identifiers and localized storefront metadata.
2. Store purchase and restore adapters behind a platform-neutral interface.
3. Server-side transaction and renewal verification.
4. Subscription, entitlement, allowance-ledger, reservation, and audit database
   migrations with tested downgrade behavior.
5. Owner-scoped plan and usage APIs.
6. Webhook reconciliation, replay protection, grace periods, refunds, revocation,
   account transfer behavior, and restore-purchase tests.
7. Privacy-safe analytics, budget alerts, accessibility review, and physical
   purchase-sandbox qualification on Android and iOS.
