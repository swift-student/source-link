#!/bin/bash
# Import a Developer ID identity into a temporary CI keychain; never print secrets.
set -euo pipefail
: "${APPLE_CERTIFICATE_P12_BASE64:?}" "${APPLE_CERTIFICATE_PASSWORD:?}"
: "${NOTARY_KEY_P8:?}" "${NOTARY_KEY_ID:?}" "${NOTARY_ISSUER_ID:?}"
umask 077
keychain="$RUNNER_TEMP/source-link-signing.keychain-db"
certificate="$RUNNER_TEMP/source-link-signing.p12"
key="$RUNNER_TEMP/source-link-notary.p8"
password=$(openssl rand -hex 32)
echo "::add-mask::$password"
printf '%s' "$APPLE_CERTIFICATE_P12_BASE64" | base64 --decode > "$certificate"
printf '%s' "$NOTARY_KEY_P8" > "$key"
security create-keychain -p "$password" "$keychain"
security set-keychain-settings -lut 21600 "$keychain"
security unlock-keychain -p "$password" "$keychain"
security import "$certificate" -P "$APPLE_CERTIFICATE_PASSWORD" -T /usr/bin/codesign -T /usr/bin/security -t cert -f pkcs12 -k "$keychain"
security set-key-partition-list -S apple-tool:,apple:,codesign: -k "$password" "$keychain" >/dev/null
security list-keychains -d user -s "$keychain" login.keychain-db
identity=$(security find-identity -v -p codesigning "$keychain" | \
  sed -nE 's/.* ([A-F0-9]{40}) "Developer ID Application:.*\(94ZMA2MYR4\)"/\1/p')
[[ "$identity" =~ ^[A-F0-9]{40}$ ]] || { echo 'Expected one Developer ID Application identity for team 94ZMA2MYR4' >&2; exit 1; }
printf 'SIGNING_IDENTITY=%s\nSIGNING_KEYCHAIN=%s\nNOTARY_KEY_PATH=%s\n' "$identity" "$keychain" "$key" >> "$GITHUB_ENV"
rm -f "$certificate"
