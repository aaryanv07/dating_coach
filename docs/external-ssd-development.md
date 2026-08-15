# External SSD Development Environment

The ConvoCoach development workload is configured to run from the external
APFS volume mounted at `/Volumes/ConvoCoachDev`.

## SSD-backed paths

- Active repository: `/Volumes/ConvoCoachDev/dating_coach_github`
- Flutter SDK: `/Volumes/ConvoCoachDev/Developer/toolchains/flutter`
- Android SDK: `/Volumes/ConvoCoachDev/Developer/android/sdk`
- Android Studio: `/Volumes/ConvoCoachDev/Developer/Applications/Android Studio.app`
- Xcode: `/Volumes/ConvoCoachDev/Applications/Xcode.app`
- Gradle cache: `/Volumes/ConvoCoachDev/tooling/gradle-cache`
- Pub cache: `/Volumes/ConvoCoachDev/tooling/pub-cache`
- CocoaPods cache: `/Volumes/ConvoCoachDev/Developer/caches/cocoapods`
- Xcode DerivedData: `/Volumes/ConvoCoachDev/Developer/caches/xcode/DerivedData`
- Xcode iOS Device Support: `/Volumes/ConvoCoachDev/Developer/caches/xcode/iOS DeviceSupport`
- CoreSimulator user data: `/Volumes/ConvoCoachDev/Developer/caches/xcode/CoreSimulator`
- Development temporary directory: `/Volumes/ConvoCoachDev/Developer/tmp`
- ELLIS documents, caches, verification logs, and legacy archives:
  `/Volumes/ConvoCoachDev/ELLIS`

Compatibility symlinks preserve the standard Homebrew, Applications, CocoaPods,
and Xcode paths. Shell configuration is loaded from
`~/.config/convocoach/ssd-env.zsh` by `~/.zprofile` and `~/.zshrc`. The loader
activates only while the SSD mount is present, so a disconnected SSD does not
leave every shell with invalid environment variables.

## Before development

1. Connect the SSD and confirm it is mounted as `/Volumes/ConvoCoachDev`.
2. Open a new Terminal window.
3. Run `flutter doctor -v` and confirm that Flutter, Android, and Xcode resolve
   to the SSD paths above.
4. Run `flutter devices` before device testing.

For the repository-managed toolchain and local AI runtime, run:

```bash
cd /Volumes/ConvoCoachDev/dating_coach_github
./scripts/setup_local_development.zsh
./scripts/configure_local_ai_secrets.zsh
```

The configuration helper stores the OpenRouter key, OpenRouter pseudonym secret, and local
debug bearer token in macOS Keychain, not on the SSD. Start the local SQLite
development server and a connected-device build in separate terminals:

```bash
./scripts/run_local_backend.zsh
./scripts/run_local_mobile.zsh --device-id <flutter-device-id>
```

The launch scripts prefer the Mac's Bonjour `.local` hostname and fall back to
its current LAN address. The backend allowlist includes both. This keeps an
installed local iPhone build usable when DHCP changes the Mac's numeric address;
both devices must still share a local network and iOS Local Network permission
must remain enabled for ConvoCoach.

The command above is a debug session and must remain attached to Flutter/Xcode.
iOS terminates a debug Flutter engine launched independently from the Home
Screen. To install a build that can be reopened without tooling while retaining
the local API configuration, use:

```bash
./scripts/run_local_mobile.zsh --profile --device-id <flutter-device-id>
```

Profile is for local physical-device qualification only; App Store distribution
still requires the production release configuration and distribution signing.
Xcode and macOS still create small result bundles and temporary files on the
internal data volume, so keep several gigabytes free there even with the main
toolchain and device-support files linked to the SSD.

SQLite setup uses `Base.metadata.create_all` only for this non-production local
loop. Historical migrations use PostgreSQL-specific operations, so migration
qualification must use PostgreSQL. Docker bind-mounts PostgreSQL and Redis data
under `.local/` on this SSD.

Do not disconnect the SSD while Flutter, Gradle, CocoaPods, Android Studio,
Xcode, a simulator, or a repository command is running. Eject it normally after
all development applications and commands stop.

## Security boundary

The SSD is APFS but is not encrypted. Apple Keychain material, signing
credentials, Android ADB keys, and the Android debug keystore therefore remain
system-managed on the internal Mac storage. The Android upload keystore is stored
at `~/Library/Application Support/ELLIS/signing/android-upload.jks` with owner-only
permissions; the build scripts use that protected location by default. Only
synthetic qualification fixtures may be used until the SSD is encrypted. Do not
place production signing keys, tokens, real conversation screenshots, or other
private user data on the unencrypted SSD.

## Verification record

After migration, `flutter doctor -v` reported no issues and resolved Flutter,
the Android SDK, Android Studio's JDK, and Xcode from the external volume. The
backend quality suite, all 165 backend tests, Flutter formatting and analysis,
all 110 Flutter tests, the Phase 6A reference benchmark, the production-configured
Android AAB build, and the iOS no-codesign device build passed from the SSD-backed
environment.

Physical Android and iOS devices were not connected during this verification.
Phase 6A.3 remains blocked until the required repeated physical-device suites
pass.

On 2026-07-27, the Phase 17 PostgreSQL migration upgraded through
`20260727_0005`, passed `alembic check`, downgraded to `20260715_0004`, and
re-upgraded on the SSD-backed Docker bind mount. Android debug and iOS simulator
debug builds also completed from the SSD. This does not replace the mandatory
physical native extraction suites or distribution signing.
