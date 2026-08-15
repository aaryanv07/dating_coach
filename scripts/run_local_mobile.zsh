#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
FLUTTER="/Volumes/ConvoCoachDev/Developer/toolchains/flutter/bin/flutter"
if [[ ! -x "$FLUTTER" ]]; then
  FLUTTER="$(command -v flutter || true)"
fi
if [[ -z "$FLUTTER" ]]; then
  print -u2 "Flutter was not found."
  exit 1
fi
TOKEN="$(security find-generic-password -a "$USER" -s convocoach.local.auth-token -w 2>/dev/null || true)"
if [[ -z "$TOKEN" ]]; then
  print -u2 "Missing local bearer token. Run scripts/configure_local_ai_secrets.zsh first."
  exit 1
fi
LAN_IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true)"
if [[ -z "$LAN_IP" ]]; then
  print -u2 "No Wi-Fi/Ethernet LAN address was found."
  exit 1
fi
LOCAL_HOST="$(scutil --get LocalHostName 2>/dev/null || true)"
if [[ -n "$LOCAL_HOST" && ! "$LOCAL_HOST" =~ '^[A-Za-z0-9-]+$' ]]; then
  print -u2 "The Mac local hostname contains unsupported characters."
  exit 1
fi
LOCAL_HOST="${LOCAL_HOST:l}"
API_HOST="${LOCAL_HOST:+$LOCAL_HOST.local}"
API_HOST="${API_HOST:-$LAN_IP}"

cd "$ROOT/apps/mobile"
exec "$FLUTTER" run \
  --dart-define=CONVOCOACH_ENVIRONMENT=local \
  --dart-define=CONVOCOACH_MOCK_MODE=true \
  --dart-define=CONVOCOACH_AUTHENTICATION_MODE=mock \
  --dart-define=CONVOCOACH_COACH_PREVIEW_ENABLED=true \
  --dart-define=CONVOCOACH_API_BASE_URL="http://$API_HOST:8000" \
  --dart-define=CONVOCOACH_API_ACCESS_TOKEN="$TOKEN" \
  "$@"
