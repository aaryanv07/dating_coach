#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
PYTHON="$ROOT/.venv/bin/python"
if [[ ! -x "$PYTHON" ]]; then
  print -u2 "Run scripts/setup_local_development.zsh first."
  exit 1
fi

keychain_value() {
  security find-generic-password -a "$USER" -s "$1" -w 2>/dev/null || {
    print -u2 "Missing Keychain item: $1"
    print -u2 "Run scripts/configure_local_ai_secrets.zsh first."
    exit 1
  }
}

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

mkdir -p "$ROOT/.local"
chmod 700 "$ROOT/.local"
export APP_ENVIRONMENT=local
export DATABASE_URL="sqlite+aiosqlite:///$ROOT/.local/convocoach.db"
export REDIS_URL="redis://127.0.0.1:6379/0"
export DEVELOPMENT_AUTH_TOKEN="$(keychain_value convocoach.local.auth-token)"
export DEVELOPMENT_AUTH_SUBJECT="local-device-user"
export DEVELOPMENT_AUTH_EMAIL="local-device@convocoach.invalid"
export AI_COACHING_ENABLED=true
export AI_MOCK_EXECUTION_ENABLED=false
export AI_PROVIDER_MODE=openrouter_tiered
export AI_USAGE_ENFORCEMENT_ENABLED=true
export OPENROUTER_FREE_MODEL="${OPENROUTER_FREE_MODEL:-openai/gpt-4o-mini}"
export OPENROUTER_PAID_MODEL="${OPENROUTER_PAID_MODEL:-openai/gpt-5.6-terra}"
export OPENROUTER_API_KEY="$(keychain_value convocoach.openrouter.api-key)"
export OPENROUTER_USER_IDENTIFIER_SECRET="$(keychain_value convocoach.openrouter.user-secret)"
export ALLOWED_HOSTS="localhost,127.0.0.1,$LAN_IP${LOCAL_HOST:+,$LOCAL_HOST.local}"

(cd "$ROOT/backend" && "$PYTHON" -m app.db.local_bootstrap)
print "ConvoCoach API: http://$LAN_IP:8000"
if [[ -n "$LOCAL_HOST" ]]; then
  print "Stable local URL: http://$LOCAL_HOST.local:8000"
fi
print "Keep this terminal open while the phone app is running."
cd "$ROOT/backend"
exec "$PYTHON" -m uvicorn app.main:app --host 0.0.0.0 --port 8000
