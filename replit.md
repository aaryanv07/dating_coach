# ConvoCoach

Privacy-conscious mobile coaching product for healthier dating communication.
Imported from GitHub; monorepo layout:

- `apps/mobile/` — Flutter (Android/iOS) app
- `backend/` — FastAPI service (needs PostgreSQL + Redis; upstream uses docker-compose, which is unavailable on Replit)
- `design/tokens/`, `docs/` — design tokens and documentation

## Environment notes
- Flutter is NOT installed in this Replit environment — the mobile app cannot be built/run/tested here. Verify with `flutter analyze` / `flutter test` locally or in CI (`.github/workflows/`).
- Backend runs on Replit: workflow "Start application" runs Alembic migrations then uvicorn on port 5000 (webview shows `/docs`). It rewrites `DATABASE_URL` to the `postgresql+asyncpg://` scheme and strips `sslmode` inline, since Replit's managed PostgreSQL exposes a plain `postgresql://` URL. Redis is not actually required — readiness only checks the env var, which has a default.

## UI/UX direction (Aug 2026)
The mobile app was redesigned to a vibrant, RizzGPT-inspired look:
- Dark-first (default `ThemeMode.dark`), deep-violet backgrounds with glowing colour orbs (`core/widgets/app_background.dart`)
- Brand palette: hot pink `#FF2D78` → electric purple `#8B5CF6`, neon cyan accent (`core/theme/app_colors.dart`, incl. gradients + glow/glass tokens)
- Gradient/glow primary buttons, glass secondary (`core/widgets/app_button.dart`); glass gradient cards with `highlight` glow option (`app_card.dart`)
- Gradient brand mark + `GradientText` helper (`app_brand.dart`, `app_typography.dart`)
- New motion widgets: `AppPopIn`, `AppAmbientPulse`, `AppStaggeredColumn`, staggered `AppReveal(delay:)` — all respect reduced-motion
- Pill buttons, 20px card radii, livelier durations (`app_tokens.dart`); bolder tighter typography
- Redesigned splash, onboarding, home, bottom nav (gradient Create orb, "Chats" label)

## User preferences
- Wants vibrant, animated RizzGPT-style UI/UX in the mobile app.
