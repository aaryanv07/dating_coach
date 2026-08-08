---
name: Flutter tooling in this Replit env
description: How to syntax-check Flutter/Dart code when flutter is not on PATH
---
Flutter is not installed on PATH in this workspace (see replit.md); the app can't be built/tested here.
**Why:** environment intentionally has no Flutter toolchain; verification happens locally/CI.
**How to apply:** for a quick syntax gate, use the Dart binary bundled in a nix-store Flutter SDK, e.g.
`/nix/store/5a2g6m1m9f71kc454wm83pd99ashaw6g-flutter-3.29.3-unwrapped/bin/dart format <paths>` — `dart format` fails on syntax errors, so a clean run means the files parse. `dart analyze` won't work without pub deps/network.
Note: `dart format` reformats every file it touches — revert unrelated format-only churn with `git checkout --`.
