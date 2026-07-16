# ConvoCoach Repository Rules

These rules apply to every file and future change in this repository. The build
prompt is the product source of truth once it contains requirements. Until then,
these rules and the explicit phase request define the safe baseline. A task must
not quietly advance into a later phase.

## Product rules

- Build a communication coach, not a system for manipulation, impersonation,
  surveillance, or guaranteed romantic outcomes.
- Preserve user agency. Suggestions are drafts that users review and choose to
  send; the product must not send messages on a user's behalf by default.
- Favor empathy, clarity, consent, boundaries, and honest self-expression over
  engagement, reply-rate, or match-rate optimization.
- Never rank a person's worth, desirability, attractiveness, or compatibility as
  an objective fact. Explain uncertainty in generated interpretations.
- Do not infer sensitive traits, diagnoses, intent, or emotions from messages as
  fact. Present observations as limited, contestable signals.
- The dating product is for adults. Do not design flows that facilitate romantic
  or sexual interactions involving minors.
- Refuse or redirect features that enable harassment, coercion, stalking,
  deception, non-consensual sexual content, or evasion of another person's
  boundaries.

## Privacy and data rules

- Collect the minimum data needed for an explicit user action. Conversation
  content is highly sensitive data.
- Never ingest contacts, notifications, private messages, screenshots, or account
  data without a clear user-initiated action and informed consent.
- Do not retain raw conversation content by default. Any retention must have a
  documented purpose, bounded duration, deletion path, and user-facing consent.
- Keep imported screenshot bytes on-device and temporary. Clear them when an
  import is abandoned or after its reviewed, normalized messages are saved;
  never send screenshot paths or bytes to the Phase 4 or Phase 5 backend.
- Never log message bodies, credentials, tokens, full prompts, or other sensitive
  payloads. Use redacted metadata and correlation IDs for diagnostics.
- Keep secrets out of source control. Read configuration from environment
  variables and provide only safe examples.
- Do not use user data to train models by default. Any external AI processor must
  be documented, minimized, contractually appropriate, and disclosed before data
  is sent.
- Encrypt sensitive data in transit and at rest when persistence is introduced.
  Access must be least-privilege and auditable.
- Product flows that create stored personal data must include export and deletion
  requirements before release.

## Design rules

- The interface should feel calm, private, inclusive, and direct. Do not use
  shame, pressure, fake urgency, manipulative streaks, or dark patterns.
- Support light and dark themes from shared semantic tokens. Do not hard-code
  theme colors inside feature widgets.
- Meet WCAG 2.2 AA contrast targets, preserve text resizing, provide semantic
  labels, and maintain touch targets of at least 44 by 44 logical pixels.
- Color must not be the only carrier of meaning. Error and status states need
  text or semantic icon support.
- Respect reduced-motion preferences. Motion should clarify state changes, remain
  brief, and never block an action.
- Keep copy non-judgmental. Clearly distinguish user-provided content, generated
  suggestions, uncertainty, and safety guidance.
- Label conversation readiness as data quality only. It must never imply
  relationship health, compatibility, interest, or likely success.

## Testing rules

- Add or update tests for every changed behavior. Regression fixes require a test
  that fails before the fix when practical.
- Keep tests deterministic and independent of live networks, external AI models,
  real user content, and shared mutable services.
- Extraction qualification fixtures must be original and synthetic. Benchmark
  reports may contain metrics and fixture IDs, but never screenshot bytes,
  transcripts, source paths, or source hashes.
- Test privacy and safety boundaries, error states, empty states, theme behavior,
  accessibility semantics, and reduced motion as those surfaces are introduced.
- Backend changes must pass formatting, linting, static typing, and tests. Flutter
  changes must pass Dart formatting, `flutter analyze`, and `flutter test`.
- CI is the minimum gate, not a substitute for focused local verification.

## Engineering rules

- Keep the monorepo boundaries explicit: `apps/mobile`, `backend`, `design`, and
  `docs`. Shared contracts must be versioned and documented.
- Prefer small, typed modules and explicit dependencies. Avoid abstractions until
  they remove demonstrated duplication or enforce a real boundary.
- Use structured parsers and serializers for structured data. Do not parse JSON,
  URLs, or protocol payloads with ad hoc string manipulation.
- Validate all external input at the boundary. Return stable, documented errors
  without leaking internals or sensitive data.
- Configuration belongs in environment variables. Defaults may be safe for local
  development but must not weaken production security.
- Database schema changes require migrations, rollback consideration, and tests.
  Redis is a disposable cache or coordination layer, never the sole durable store.
- Keep dependency versions bounded, review generated lockfiles, and avoid adding
  dependencies for behavior supported clearly by the standard library.
- Maintain health endpoints that distinguish process liveness from actual
  readiness. Do not claim dependency readiness unless connectivity is checked.
- Keep commits and changes scoped to the active phase. Phase 2 features require an
  explicit Phase 2 request.
- Do not invoke analysis, scoring, or generation on imported conversation data
  until the user has corrected and explicitly confirmed the normalized message
  sequence. OCR adapters and analysis adapters must remain separate boundaries.
- Preserve the versioned conversation-event boundary. Reactions, structural
  items, deleted markers, and unknown events must not be projected as ordinary
  messages, and event persistence must not introduce an undocumented dual write
  with the legacy message tables.

## Repository map

- `apps/mobile`: the only customer-facing application, built with Flutter.
- `backend`: the FastAPI service. It is not a customer-facing website.
- `design/tokens`: platform-neutral semantic design and motion values.
- `docs`: product, architecture, design, privacy, testing, and decision records.
- `.github/workflows`: required automated quality gates.

## Motion rules

- Normal interaction motion must stay between 150 and 300 milliseconds. Loading
  loops may be longer but must remain subtle.
- Use motion only for navigation, state change, hierarchy, progress, completion,
  or clear cause and effect.
- Never block interaction for decorative animation. Limit each screen to three
  major animated moments and avoid constant glow, bounce, parallax, or particles.
- Prefer transform and opacity animation, isolate repeating painters, and review
  behavior with reduced motion enabled.

## Future AI output rules

- AI outputs must use validated structured schemas, identify evidence, state
  uncertainty, and provide alternative interpretations.
- Never claim certainty about romantic interest or another person's internal
  state. Never log raw prompts or private conversation content.
- Provider failures must return a safe processing error. Route handlers must not
  call AI providers directly.

## Commands

- Mobile: `flutter pub get`, `dart format .`, `flutter analyze`, `flutter test`.
- Backend: `ruff format backend`, `ruff check backend`, then from `backend/`,
  `mypy app tests` and `pytest`.
- Infrastructure: `docker compose --env-file .env.example config --quiet`.
- Migrations: from `backend/`, run `alembic upgrade head` and `alembic check`
  against PostgreSQL. Verify downgrade behavior for every new revision.
- Phase 6A reference benchmark: from `apps/mobile/`, run
  `flutter test benchmark/phase6a_reference_benchmark_test.dart`.
- Native extraction qualification is not complete until the documented Android
  and iOS physical-device suites have produced content-free reports and passed
  every required gate.

## Documentation rules

- Update relevant architecture, design, privacy, testing, and decision documents
  in the same change as behavior.
- Record assumptions and limitations. Never describe unexecuted checks as passed.
- Never use real conversations as fixtures, bypass resource ownership checks,
  store screenshots indefinitely, or sacrifice accessibility for aesthetics.

## Definition of done

A change is complete only when its behavior is implemented, relevant documentation
is current, available checks have passed, failures have been fixed or reported,
and unverified behavior is described as a limitation rather than a success.
