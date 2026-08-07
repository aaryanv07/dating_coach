#!/bin/zsh
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  print -u2 "This helper requires macOS Keychain."
  exit 1
fi

print "Enter the OpenRouter API key when Keychain prompts. Input is hidden."
security add-generic-password -U -a "$USER" -s convocoach.openrouter.api-key \
  -l "ConvoCoach local OpenRouter API key" -w
USER_IDENTIFIER_SECRET="$(openssl rand -hex 32)"
AUTH_TOKEN="$(openssl rand -hex 32)"
security add-generic-password -U -a "$USER" -s convocoach.openrouter.user-secret \
  -l "ConvoCoach local OpenRouter pseudonym secret" -w "$USER_IDENTIFIER_SECRET"
security add-generic-password -U -a "$USER" -s convocoach.local.auth-token \
  -l "ConvoCoach local development auth token" -w "$AUTH_TOKEN"
unset USER_IDENTIFIER_SECRET AUTH_TOKEN
print "The pseudonym secret and local bearer token were generated automatically."
print "All secrets are stored in macOS Keychain, not on the external SSD or in Git."
