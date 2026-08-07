FROM python:3.13-slim-bookworm@sha256:9d7f287598e1a5a978c015ee176d8216435aaf335ed69ac3c38dd1bbb10e8d64

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /srv/convocoach

COPY backend/requirements.lock ./requirements.lock
RUN python -m pip install --require-hashes --no-deps -r requirements.lock

COPY backend/app ./app
COPY backend/migrations ./migrations
COPY backend/alembic.ini ./alembic.ini

RUN addgroup --system --gid 10001 convocoach \
    && adduser --system --uid 10001 --ingroup convocoach --no-create-home convocoach \
    && chown -R convocoach:convocoach /srv/convocoach

USER 10001:10001
EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=3s --start-period=20s --retries=3 \
  CMD ["python", "-c", "import os, urllib.request; host = next((item.strip() for item in os.getenv('ALLOWED_HOSTS', '').split(',') if item.strip()), '127.0.0.1'); request = urllib.request.Request('http://127.0.0.1:8000/health/live', headers={'Host': host}); urllib.request.urlopen(request, timeout=2).read()"]

CMD ["python", "-m", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--no-server-header"]
