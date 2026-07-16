# Windows development handoff

## Scope

Windows can be the primary workstation for the shared Flutter application,
FastAPI backend, automated tests, Android builds, and physical Android
qualification. It cannot build, sign, install, or physically qualify the iOS
application. The same repository must later return to a Mac with full Xcode for
the required physical-iPhone suite.

Phase 6A.3 therefore remains `BLOCKED` until both platforms pass. Moving to
Windows does not authorize Phase 6B and does not change the product, privacy, or
testing gates in `AGENTS.md`.

## Recommended workstation layout

Clone into a short local path that is not synchronized by OneDrive, iCloud, or
another file-on-demand service:

```powershell
New-Item -ItemType Directory -Force C:\dev | Out-Null
Set-Location C:\dev
git clone --branch codex/windows-phase6a-handoff `
  https://github.com/aaryanv07/dating_coach.git
Set-Location dating_coach
```

After the migration pull request is merged, a normal clone of `main` replaces
the branch-specific command.

Do not put the active checkout on a removable USB flash drive. Flutter, Gradle,
Docker, PostgreSQL, and Git perform many small writes and require a stable local
filesystem.

## Required software

Install these tools before opening the project:

- Git for Windows;
- Flutter stable `3.44.6`, matching CI and the current lockfile;
- Android Studio with its bundled JDK;
- Android SDK Platform 36, Build Tools 36, platform-tools, command-line tools,
  NDK `28.2.13676358`, and CMake `3.22.1`;
- Python 3.13, with Python 3.12 also supported by the backend metadata; and
- Docker Desktop using the WSL 2 backend.

Add Flutter and Git to `PATH`, then restart PowerShell. In Android Studio's SDK
Manager, install the listed Android packages and accept the SDK licenses.

Verify the workstation:

```powershell
git --version
flutter --version
flutter doctor -v
py -3.13 --version
docker --version
docker compose version
adb version
```

`flutter doctor` may report that iOS is unavailable. That is expected on
Windows and must not be represented as an iOS pass.

## Clone integrity

From the repository root:

```powershell
git status
git rev-parse HEAD
git lfs version 2>$null
```

This repository currently does not require Git LFS. `git status` should report
a clean worktree before development begins.

## Backend setup

Use the checked-in safe local configuration:

```powershell
Copy-Item .env.example .env
py -3.13 -m venv .venv
.\.venv\Scripts\python.exe -m pip install --upgrade pip
.\.venv\Scripts\python.exe -m pip install -e "backend[dev]"
docker compose --env-file .env up -d
```

Apply and verify the database migrations:

```powershell
Push-Location backend
..\.venv\Scripts\python.exe -m alembic upgrade head
..\.venv\Scripts\python.exe -m alembic check
Pop-Location
```

Run the backend:

```powershell
.\.venv\Scripts\python.exe -m uvicorn app.main:app `
  --app-dir backend --reload --env-file .env
```

The local API is available at `http://127.0.0.1:8000`, with liveness at
`/health/live`, readiness at `/health/ready`, and OpenAPI at `/docs`.

## Mobile setup and platform-independent verification

From the repository root:

```powershell
Set-Location apps\mobile
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter test benchmark\phase6a_reference_benchmark_test.dart
flutter build bundle --release
dart run tool\run_phase6a2_native.dart
```

The final readiness command is expected to return exit code `2` until a
supported physical Android device is attached. It will also report iOS as
unavailable on Windows; that is a truthful platform limitation, not a test
failure to suppress.

Run the backend gates from the repository root:

```powershell
.\.venv\Scripts\ruff.exe format --check backend
.\.venv\Scripts\ruff.exe check backend
Push-Location backend
..\.venv\Scripts\mypy.exe app tests
..\.venv\Scripts\pytest.exe -W error
Pop-Location
docker compose --env-file .env.example config --quiet
```

## Physical Android preparation

1. Enable Developer options and USB debugging on the Android phone.
2. Connect the phone directly to the Windows PC with a data-capable cable.
3. Unlock the phone and accept its USB-debugging RSA prompt.
4. Confirm that both Android and Flutter see the same physical device:

```powershell
adb devices -l
flutter devices
```

Use the device identifier reported by those commands:

```powershell
Set-Location apps\mobile
dart run tool\run_phase6a2_android.dart --device-id=<PHYSICAL_DEVICE_ID>
```

The qualification output under `build\phase6a-readiness` and
`build\phase6a-benchmark\android` is content-free and ignored by Git. Do not
commit device reports, screenshot bytes, transcripts, source paths, or source
hashes.

## Known Android build blocker

The last macOS preflight reached Android dependency compilation and failed in
`irondash_engine_context` `0.5.5`: its CargoKit Gradle script calls the removed
`Project.exec()` API under Gradle `9.1`. Moving to Windows does not prove that
this compatibility defect is resolved.

Do not silently change the application's minimum SDK, downgrade or replace
dependencies, or patch generated package-cache files. A backward-compatible,
source-controlled fix requires separate phase-scoped authorization, focused
tests, and documentation. Until that fix and the two required physical-device
runs pass, Android qualification remains incomplete.

## iOS handback

Keep all shared changes in Git. When a Mac with sufficient stable storage and
full Xcode is available:

1. pull the same reviewed commit;
2. install only the required iOS platform support initially;
3. connect and trust a supported physical iPhone;
4. configure signing without committing credentials or provisioning secrets;
5. run the documented iOS suite twice; and
6. complete the physical accessibility smoke checks.

Phase 6A.3 passes only after the reviewed Android and iOS content-free reports
meet every documented gate.
