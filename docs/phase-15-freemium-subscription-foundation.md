# Phase 15: Freemium and Subscription Foundation

## Status

Phase 15 implements the approved plan catalog and an honest plan preview. It is
a non-purchasing foundation and does not authorize launch or controlled traffic.

## Implemented scope

- immutable, versioned, content-free backend plan contracts;
- exact INR reference prices stored as integer minor units;
- closed welcome, Free, and Plus catalog definitions;
- exact allowances and reset-period metadata;
- a deterministic allowance evaluator with fail-closed exhaustion behavior;
- explicit non-paywalled safety and privacy capabilities;
- a mobile preview reachable from Settings;
- monthly/yearly Plus preview pricing and allowance comparison;
- explicit copy stating that no payment information is collected;
- reduced-width, large-text, semantics, and navigation coverage; and
- commercial, privacy, counting, cost, and future-live-billing documentation.

## Explicit exclusions

- no live purchase, restore, renewal, cancellation, refund, or webhook behavior;
- no Apple StoreKit or Google Play Billing dependency;
- no trusted client entitlement or quota counter;
- no route, persistence, database table, schema migration, Redis use, or audit
  record;
- no receipt or signed-transaction verification;
- no external AI provider, model call, generated coaching, or billable action;
- no production authentication or distribution signing; and
- no release-gate or controlled-launch authorization.

The checked-in catalog sets every plan's `purchase_enabled` value to false. A
later phase must replace preview prices with localized storefront data and make
the backend the only entitlement and reservation authority.

## Verification

Run the focused checks:

```bash
ruff format --check backend/app/subscriptions backend/tests/test_phase15_subscription_foundation.py
ruff check backend/app/subscriptions backend/tests/test_phase15_subscription_foundation.py
(cd backend && mypy app/subscriptions tests/test_phase15_subscription_foundation.py)
(cd backend && pytest -W error tests/test_phase15_subscription_foundation.py)
(cd apps/mobile && flutter test test/phase15_subscription_preview_test.dart)
```

Then run the complete backend and mobile quality suites required by `AGENTS.md`.
Record only commands actually executed and results actually observed.

### Verification record — 2026-07-26

- focused Phase 15 backend checks passed, including 10 tests;
- `ruff format --check backend` and `ruff check backend` passed;
- `mypy app tests` passed for 91 source files;
- the complete backend suite passed with 175 tests;
- source-scoped Dart formatting checked 142 files with no changes;
- `flutter analyze` passed with no issues;
- the complete Flutter suite passed with 121 tests; and
- `git diff --check` passed.

No migration check was required because this phase adds no schema revision.

The separate Phase 6A iPhone qualification suite also completed two consecutive
native runs on an iPhone 13 Pro Max. The comparison reported `NO_REGRESSION`, but
both runs remain `BLOCKED`: message extraction, event classification,
minimum-fixture extraction, speaker assignment, timestamp, and warning accuracy
missed their required gates. Android physical qualification was not run because
no Android device was connected. These results do not authorize a release.
