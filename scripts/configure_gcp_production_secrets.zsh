#!/bin/zsh
set -euo pipefail

if [[ -z "${CONVOCOACH_GCP_PROJECT_ID:-}" ]]; then
  print -u2 "Set CONVOCOACH_GCP_PROJECT_ID to the dedicated production project."
  exit 1
fi

if ! command -v gcloud >/dev/null 2>&1; then
  print -u2 "Google Cloud CLI is not available."
  exit 1
fi

active_project="$(gcloud config get-value project 2>/dev/null)"
active_account="$(gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null)"
if [[ "$active_project" != "$CONVOCOACH_GCP_PROJECT_ID" || -z "$active_account" ]]; then
  print -u2 "Select the production project and an authorized Google Cloud account first."
  exit 1
fi

secret_name="convocoach-openrouter-api-key"
if ! gcloud secrets describe "$secret_name" --project "$CONVOCOACH_GCP_PROJECT_ID" >/dev/null 2>&1; then
  print -u2 "Run the Terraform foundation step first; the production secret container is absent."
  exit 1
fi

read -s "openrouter_key?Paste the production OpenRouter API key (input is hidden): "
print
if [[ ${#openrouter_key} -lt 20 || "$openrouter_key" == *[[:space:]]* ]]; then
  unset openrouter_key
  print -u2 "The API key did not pass the content-free shape check."
  exit 1
fi

print -rn -- "$openrouter_key" | gcloud secrets versions add "$secret_name" \
  --project "$CONVOCOACH_GCP_PROJECT_ID" \
  --data-file=- >/dev/null
unset openrouter_key

print "production_secret_configuration=complete"
print "No secret value was printed or written to the repository."
