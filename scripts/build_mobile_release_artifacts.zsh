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

python3 - "$CONFIG" <<'PY'
import json
import sys
from urllib.parse import urlparse

with open(sys.argv[1], encoding="utf-8") as handle:
    config = json.load(handle)
api = urlparse(str(config.get("CONVOCOACH_API_BASE_URL", "")))
host = (api.hostname or "").lower()
reserved = (
    not host
    or host in {"example.com", "example.org", "example.net", "localhost", "127.0.0.1", "::1"}
    or host.endswith((".example.com", ".example.org", ".example.net", ".invalid"))
)
if api.scheme != "https" or reserved or api.username or api.query or api.fragment:
    raise SystemExit("Release artifacts require a real HTTPS production API URL.")
PY

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
