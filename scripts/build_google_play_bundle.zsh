#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
MOBILE="$ROOT/apps/mobile"
CONFIG="${CONVOCOACH_MOBILE_PRODUCTION_CONFIG:-$MOBILE/config/production.google-play.json}"
KEYSTORE="${CONVOCOACH_ANDROID_UPLOAD_KEYSTORE:-$HOME/Library/Application Support/ELLIS/signing/android-upload.jks}"
ALIAS="${CONVOCOACH_ANDROID_UPLOAD_ALIAS:-convocoach-upload}"
ACCOUNT="${USER:-$(id -un)}"
OUTPUT_DIR="$ROOT/release/google-play"

if [[ ! -f "$CONFIG" ]]; then
  print -u2 "Create the ignored Google Play configuration from apps/mobile/config/production.google-play.example.json."
  exit 1
fi
if [[ ! -f "$KEYSTORE" ]]; then
  print -u2 "Create the protected upload key with scripts/create_android_upload_key.zsh."
  exit 1
fi
if [[ -n "$(git -C "$ROOT" status --porcelain)" ]]; then
  print -u2 "Google Play artifacts require a reviewed clean source revision."
  exit 1
fi

python3 - "$CONFIG" <<'PY'
import json
import sys
from urllib.parse import urlparse

path = sys.argv[1]
with open(path, encoding="utf-8") as handle:
    config = json.load(handle)
required = {
    "CONVOCOACH_ENVIRONMENT": "production",
    "CONVOCOACH_MOCK_MODE": False,
    "CONVOCOACH_AUTHENTICATION_MODE": "oidc",
    "CONVOCOACH_BILLING_MODE": "store",
}
for key, expected in required.items():
    if config.get(key) != expected:
        raise SystemExit(f"Unsafe Google Play configuration: {key}")
for key in (
    "CONVOCOACH_API_BASE_URL",
    "CONVOCOACH_OIDC_DISCOVERY_URL",
    "CONVOCOACH_OIDC_CLIENT_ID",
    "CONVOCOACH_OIDC_AUDIENCE",
    "CONVOCOACH_OIDC_GOOGLE_CONNECTION",
    "CONVOCOACH_GOOGLE_MONTHLY_PRODUCT_ID",
    "CONVOCOACH_GOOGLE_YEARLY_PRODUCT_ID",
):
    value = config.get(key)
    if (
        not isinstance(value, str)
        or not value
        or "replace" in value.lower()
        or ".invalid" in value
        or "example.com" in value
    ):
        raise SystemExit(f"Unresolved Google Play configuration: {key}")
api = urlparse(config["CONVOCOACH_API_BASE_URL"])
if api.scheme != "https" or not api.netloc or api.username or api.query or api.fragment:
    raise SystemExit("Unsafe production API URL")
if config.get("CONVOCOACH_API_ACCESS_TOKEN", ""):
    raise SystemExit("A production bundle must not embed an access token")
PY

API_BASE_URL="$(jq -r '.CONVOCOACH_API_BASE_URL' "$CONFIG")"
OIDC_DISCOVERY_URL="$(jq -r '.CONVOCOACH_OIDC_DISCOVERY_URL' "$CONFIG")"
curl --fail --silent --show-error --max-time 15 \
  "$API_BASE_URL/health/ready" |
  jq -e '
    .status == "ready" and
    .checks.configuration == "valid" and
    .checks.database == "ready" and
    .checks.migrations == "compatible" and
    .checks.redis == "ready"
  ' >/dev/null
curl --fail --silent --show-error --max-time 15 "$OIDC_DISCOVERY_URL" |
  jq -e '
    (.issuer | type == "string") and
    (.authorization_endpoint | type == "string") and
    (.token_endpoint | type == "string") and
    (.jwks_uri | type == "string")
  ' >/dev/null

export CONVOCOACH_RELEASE_STORE_FILE="$KEYSTORE"
export CONVOCOACH_RELEASE_KEY_ALIAS="$ALIAS"
export CONVOCOACH_RELEASE_STORE_PASSWORD="$(security find-generic-password -a "$ACCOUNT" -s convocoach.android.upload.store-password -w)"
export CONVOCOACH_RELEASE_KEY_PASSWORD="$(security find-generic-password -a "$ACCOUNT" -s convocoach.android.upload.key-password -w)"
trap 'unset CONVOCOACH_RELEASE_STORE_PASSWORD CONVOCOACH_RELEASE_KEY_PASSWORD' EXIT

cd "$MOBILE"
flutter pub get
dart format --output=none --set-exit-if-changed lib test benchmark tool
flutter analyze
flutter test
flutter test benchmark/phase6a_reference_benchmark_test.dart
flutter build appbundle --release --dart-define-from-file="$CONFIG"

AAB="$MOBILE/build/app/outputs/bundle/release/app-release.aab"
[[ -f "$AAB" ]] || { print -u2 "Android App Bundle missing."; exit 1; }
MERGED_MANIFEST="$MOBILE/build/app/intermediates/merged_manifests/release/processReleaseManifest/AndroidManifest.xml"
if [[ ! -f "$MERGED_MANIFEST" ]] ||
   ! grep -q 'package="com.convocoach.convo_coach"' "$MERGED_MANIFEST" ||
   ! grep -q 'android:targetSdkVersion="36"' "$MERGED_MANIFEST"; then
  print -u2 "The release manifest does not match the approved package or target API."
  exit 1
fi
jarsigner -verify "$AAB" >/dev/null 2>&1
SIGNED_FINGERPRINT="$(keytool -printcert -jarfile "$AAB" 2>/dev/null | awk -F': ' '/SHA256:/{print $2; exit}')"
KEY_FINGERPRINT="$(keytool -list -keystore "$KEYSTORE" -storepass:env CONVOCOACH_RELEASE_STORE_PASSWORD -alias "$ALIAS" 2>/dev/null | awk -F': ' '/SHA-256:/{print $2; exit}')"
if [[ -z "$SIGNED_FINGERPRINT" || "$SIGNED_FINGERPRINT" != "$KEY_FINGERPRINT" ]]; then
  print -u2 "The bundle signer does not match the protected upload key."
  exit 1
fi
mkdir -p "$OUTPUT_DIR"
cp "$AAB" "$OUTPUT_DIR/convocoach-google-play.aab"
shasum -a 256 "$OUTPUT_DIR/convocoach-google-play.aab" > \
  "$OUTPUT_DIR/convocoach-google-play.aab.sha256"

print "google_play_bundle=verified"
print "artifact=$OUTPUT_DIR/convocoach-google-play.aab"
print "source_revision=$(git -C "$ROOT" rev-parse HEAD)"
