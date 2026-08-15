#!/bin/zsh
set -euo pipefail

base_url="${1:-}"
if [[ "$base_url" != https://* || "$base_url" == *\?* || "$base_url" == *\#* ]]; then
  print -u2 "Provide an exact HTTPS API origin."
  exit 1
fi

live="$(curl --fail --silent --show-error --proto '=https' --tlsv1.2 \
  --max-time 10 "$base_url/health/live")"
ready="$(curl --fail --silent --show-error --proto '=https' --tlsv1.2 \
  --max-time 10 "$base_url/health/ready")"

python3 - "$live" "$ready" <<'PY'
import json
import sys

live = json.loads(sys.argv[1])
ready = json.loads(sys.argv[2])
if live.get("status") != "ok":
    raise SystemExit("production_liveness_failed")
if ready.get("status") != "ready":
    raise SystemExit("production_readiness_failed")
checks = ready.get("checks", {})
if checks.get("database") != "ready" or checks.get("redis") != "ready":
    raise SystemExit("production_dependency_readiness_failed")
if checks.get("migrations") != "compatible":
    raise SystemExit("production_migration_readiness_failed")
print("production_endpoint=ready")
PY
