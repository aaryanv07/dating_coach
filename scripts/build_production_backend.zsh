#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
PROJECT_ID="${CONVOCOACH_GCP_PROJECT_ID:-}"
REGION="${CONVOCOACH_GCP_REGION:-asia-south1}"
REVISION="$(git -C "$ROOT" rev-parse HEAD)"

if [[ -z "$PROJECT_ID" ]]; then
  print -u2 "Set CONVOCOACH_GCP_PROJECT_ID before building."
  exit 1
fi
if [[ -n "$(git -C "$ROOT" status --porcelain)" ]]; then
  print -u2 "A production artifact can only be built from a reviewed clean revision."
  exit 1
fi

image="$REGION-docker.pkg.dev/$PROJECT_ID/convocoach-backend/api:$REVISION"
gcloud builds submit "$ROOT" --project "$PROJECT_ID" --tag "$image"
digest="$(gcloud artifacts docker images describe "$image" \
  --project "$PROJECT_ID" \
  --format='value(image_summary.digest)')"
if [[ "$digest" != sha256:* ]]; then
  print -u2 "The registry did not return an immutable image digest."
  exit 1
fi
print "backend_image=$REGION-docker.pkg.dev/$PROJECT_ID/convocoach-backend/api@$digest"
