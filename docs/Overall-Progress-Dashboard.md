# Overall Progress Dashboard

Date: 2026-08-01

## Product outcome

The customer-facing `Stats` space presents one aggregate view across every saved
conversation the user chooses to track. It does not publish a score for an
individual conversation or person.

The saved-conversation detail no longer links to the earlier per-conversation
developer analytics view. That deterministic renderer remains in the codebase
for contract regression tests and internal evidence inspection, but it is not a
customer navigation destination.

The dashboard contains:

- a self-reported communication score;
- user-reported reply performance;
- the count and summary of explicitly confirmed plans;
- saved-conversation and recorded-outcome counts; and
- one optional private reflection.

The visual direction is original to ConvoCoach. Competitor references informed
the short hierarchy and premium pastel energy, but no competitor mark, asset,
exact composition, wording, or trade dress is reused.

## Calculation boundary

The communication score is the rounded arithmetic mean of three answers the
user records for each tracked outcome:

1. “Sounded like me”;
2. “Expressed my point clearly”; and
3. “Respected my boundaries.”

Each answer is an integer from 1 to 5. The aggregate is normalized to 0–100:

```text
round(sum(all three ratings) / (recorded outcomes × 15) × 100)
```

It is explicitly a self-assessment. It is not an interest, compatibility,
attraction, personality, relationship-health, or date-success score.

Reply performance is the percentage of user-recorded `reply received` outcomes
among completed `reply received` and `no reply yet` outcomes. `Still waiting`
is excluded from both the numerator and denominator, so an unresolved outcome
cannot be silently treated as failure.

A plan is confirmed only when the user selects `Explicitly confirmed`. The app
does not derive plan status from message content and does not predict whether a
date will happen or be successful.

Outcomes for deleted conversations are removed the next time the dashboard is
loaded and never remain in aggregate calculations.

## Privacy and retention

No contact, notification, account inbox, reply, or calendar data is read. Every
outcome is entered through a user-initiated form. Stored outcome metadata
contains only an opaque local conversation ID, enum choices, three bounded
ratings, and an update timestamp.

The optional reflection is limited to 1,000 characters. Outcome metadata and
the reflection are stored in iOS Keychain or Android protected credential
storage through the platform secure-storage adapter. They are not sent to the
backend or an AI provider. `Clear private stats` deletes the complete journal
without deleting saved conversations.

Signing out also clears the device journal. Successful account deletion clears
it after the authenticated backend accepts deletion; a failed server request
preserves the journal and session so the user is not shown a false success.

## Motion and accessibility

The screen has at most three major animated moments: the shared backdrop reveal,
the score gauge, and the reply-performance bar. Durations use shared 160–280 ms
tokens. Reduced-motion settings replace all three transitions with their final
static state. The score and status cards expose complete semantic labels, all
controls retain 44-point targets, large text changes the score hero to a stacked
layout, and no status depends on color alone.

## Verification

`overall_progress_dashboard_test.dart` covers deterministic aggregation,
waiting-outcome treatment, global-only presentation, explicit user recording,
large text, and reduced motion. `progress_journal_storage_test.dart` covers
protected round-trip, deletion, and fail-closed schema handling.
