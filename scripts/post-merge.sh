#!/bin/bash
# Post-merge setup: keep the Python backend environment and database in sync.
# Idempotent, non-interactive, fails fast.
set -e

cd "$(dirname "$0")/.."

# Ensure backend Python dependencies are installed (uv manages .pythonlibs).
if [ -f pyproject.toml ]; then
  uv sync 2>/dev/null || pip install alembic asyncpg fastapi python-dotenv "sqlalchemy[asyncio]" uvicorn
fi

# Apply any new database migrations against the Replit-managed PostgreSQL.
if [ -n "$DATABASE_URL" ]; then
  export DATABASE_URL="$(echo "$DATABASE_URL" \
    | sed 's|^postgresql://|postgresql+asyncpg://|; s|^postgres://|postgresql+asyncpg://|' \
    | sed 's|[?&]sslmode=[^&]*||')"
  (cd backend && python3 -m alembic upgrade head)
fi

echo "post-merge setup complete"
