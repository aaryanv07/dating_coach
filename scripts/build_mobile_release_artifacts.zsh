#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
MOBILE="$ROOT/apps/mobile"
CONFIG="${CONVOCOACH_MOBILE_PRODUCTION_CONFIG:-$MOBILE/config/production.json}"

if [[ ! -f "$CONFIG" ]]; then
  print -u2 "Create the untracked mobile production config from production.example.json."
  exit 1
fi
if [[ -n "$(git -C "$ROOT" status --porcelain)" ]]; then
  print -u2 "Release artifacts require a reviewed clean source revision."
  exit 1
fi

cd "$MOBILE"
flutter pub get
dart format --output=none --set-exit-if-changed lib test benchmark tool
flutter analyze
flutter test

flutter build appbundle --release --dart-define-from-file="$CONFIG"
flutter build ipa --release --dart-define-from-file="$CONFIG"

if [[ ! -f build/app/outputs/bundle/release/app-release.aab ]]; then
  print -u2 "Android release artifact missing."
  exit 1
fi
if ! find build/ios/archive -name '*.xcarchive' -maxdepth 2 -print -quit | grep -q .; then
  print -u2 "iOS release archive missing."
  exit 1
fi
print "mobile_release_artifacts=built"
