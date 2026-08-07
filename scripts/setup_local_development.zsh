#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
mkdir -p "$ROOT/.local/toolchains" "$ROOT/.local/cache/uv"
chmod 700 "$ROOT/.local"
PYTHON=""
for candidate in \
  /opt/homebrew/opt/python@3.12/bin/python3.12 \
  /usr/local/opt/python@3.12/bin/python3.12 \
  /opt/homebrew/bin/python3.12 \
  /usr/local/bin/python3.12; do
  if [[ -x "$candidate" ]]; then
    PYTHON="$candidate"
    break
  fi
done
if [[ -z "$PYTHON" ]]; then
  UV="$ROOT/.local/toolchains/uv/uv"
  if [[ ! -x "$UV" ]]; then
    print "Installing the uv bootstrap tool on the SSD..."
    curl -LsSf https://astral.sh/uv/install.sh | \
      env UV_UNMANAGED_INSTALL="$ROOT/.local/toolchains/uv" UV_NO_MODIFY_PATH=1 sh
  fi
  export UV_PYTHON_INSTALL_DIR="$ROOT/.local/toolchains/python"
  export UV_CACHE_DIR="$ROOT/.local/cache/uv"
  "$UV" python install 3.12
  PYTHON="$($UV python find 3.12)"
fi

if [[ ! -x "$ROOT/.venv/bin/python" ]]; then
  "$PYTHON" -m venv "$ROOT/.venv"
fi
"$ROOT/.venv/bin/python" -m pip install --upgrade pip
"$ROOT/.venv/bin/pip" install -e "$ROOT/backend[dev]"

FLUTTER="/Volumes/ConvoCoachDev/Developer/toolchains/flutter/bin/flutter"
if [[ ! -x "$FLUTTER" ]]; then
  FLUTTER="$(command -v flutter || true)"
fi
if [[ -z "$FLUTTER" ]]; then
  print -u2 "Flutter was not found."
  exit 1
fi
(cd "$ROOT/apps/mobile" && "$FLUTTER" pub get)
print "Local development dependencies are installed on the SSD."
