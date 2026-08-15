#!/bin/zsh
set -euo pipefail

KEYSTORE="${CONVOCOACH_ANDROID_UPLOAD_KEYSTORE:-$HOME/Library/Application Support/ELLIS/signing/android-upload.jks}"
ALIAS="${CONVOCOACH_ANDROID_UPLOAD_ALIAS:-convocoach-upload}"
STORE_SERVICE="convocoach.android.upload.store-password"
KEY_SERVICE="convocoach.android.upload.key-password"
ACCOUNT="${USER:-$(id -un)}"

if [[ -e "$KEYSTORE" ]]; then
  print -u2 "Upload key already exists at the protected internal path. Refusing to replace it."
  exit 1
fi

mkdir -p "${KEYSTORE:h}"
chmod 700 "${KEYSTORE:h}"
export CONVOCOACH_UPLOAD_STORE_PASSWORD="$(openssl rand -base64 36 | tr -d '\n')"
export CONVOCOACH_UPLOAD_KEY_PASSWORD="$(openssl rand -base64 36 | tr -d '\n')"

security add-generic-password -U -a "$ACCOUNT" -s "$STORE_SERVICE" \
  -w "$CONVOCOACH_UPLOAD_STORE_PASSWORD" >/dev/null
security add-generic-password -U -a "$ACCOUNT" -s "$KEY_SERVICE" \
  -w "$CONVOCOACH_UPLOAD_KEY_PASSWORD" >/dev/null

keytool -genkeypair \
  -keystore "$KEYSTORE" \
  -storetype JKS \
  -storepass:env CONVOCOACH_UPLOAD_STORE_PASSWORD \
  -keypass:env CONVOCOACH_UPLOAD_KEY_PASSWORD \
  -alias "$ALIAS" \
  -keyalg RSA \
  -keysize 4096 \
  -validity 10000 \
  -dname "CN=ConvoCoach Upload, O=ConvoCoach, C=IN" \
  -noprompt >/dev/null
chmod 600 "$KEYSTORE"
unset CONVOCOACH_UPLOAD_STORE_PASSWORD CONVOCOACH_UPLOAD_KEY_PASSWORD

print "android_upload_key=created"
print "keystore=$KEYSTORE"
print "alias=$ALIAS"
print "passwords=macos-keychain"
print "backup_required=encrypted-offline-copy"
