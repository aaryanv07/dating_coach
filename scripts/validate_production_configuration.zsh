#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
PYTHON="$ROOT/backend/.venv/bin/python"
if [[ ! -x "$PYTHON" ]]; then
  print -u2 "The backend development environment is not available."
  exit 1
fi

cd "$ROOT/backend"
APP_ENVIRONMENT=production "$PYTHON" - <<'PY'
from app.core.config import get_settings, validate_settings

validate_settings(get_settings())
print("production_configuration=valid")
PY
