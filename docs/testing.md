# Testing and Verification

Run backend checks from the repository root unless a working directory is noted.

```bash
ruff format --check backend
ruff check backend
```

Run typing and tests from `backend/`:

```bash
mypy app tests
pytest
```

Validate local infrastructure without starting containers:

```bash
docker compose --env-file .env.example config --quiet
```

Run these from `apps/mobile/`:

```bash
flutter pub get
dart format .
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

The initial backend suite covers liveness, ready and not-ready configuration,
environment parsing, and design-token JSON validity. Live dependency integration
tests are deferred until persistence clients are introduced.

The Phase 2 Flutter suite covers onboarding progression, the mandatory privacy
and age gates, mock authentication, bottom navigation, central create sheet,
light/dark tokens, state controllers, reduced motion, 200 percent text scaling,
touch targets, semantics, skeleton behavior, and empty/error/offline states.
