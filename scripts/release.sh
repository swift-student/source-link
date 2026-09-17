#!/bin/bash
# Build a universal release; optionally sign and notarize before packaging.
set -euo pipefail
version=${RELEASE_VERSION:?Set RELEASE_VERSION}
mode=${1:-dry-run}
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Version must be X.Y.Z' >&2; exit 1; }
[[ "$mode" == dry-run || "$mode" == publish ]] || exit 2
output="$PWD/.build/release"
app="$PWD/.build/release-build/Build/Products/Release/source-link.app"
mkdir -p "$output"
make generate
xcodebuild -workspace SourceLink.xcworkspace -scheme SourceLink -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath .build/release-build \
  ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO \
  MARKETING_VERSION="$version" CURRENT_PROJECT_VERSION="${GITHUB_RUN_NUMBER:-1}" build
for executable in "$app/Contents/MacOS/source-link" "$app/Contents/Helpers/source-link"; do
  architectures=" $(lipo -archs "$executable") "
  [[ "$architectures" == *' arm64 '* && "$architectures" == *' x86_64 '* ]] || {
    echo "Missing release architecture in $executable: $architectures" >&2
    exit 1
  }
done
"$app/Contents/Helpers/source-link" config validate examples/config.json
if [[ "$mode" == publish ]]; then
  : "${SIGNING_IDENTITY:?}" "${SIGNING_KEYCHAIN:?}" "${NOTARY_KEY_PATH:?}"
  : "${NOTARY_KEY_ID:?}" "${NOTARY_ISSUER_ID:?}"
  for target in "$app/Contents/Helpers/source-link" "$app"; do
    codesign --force --sign "$SIGNING_IDENTITY" --keychain "$SIGNING_KEYCHAIN" \
      --options runtime --timestamp "$target"
  done
  codesign --verify --deep --strict --verbose=2 "$app"
  ditto -c -k --sequesterRsrc --keepParent "$app" "$RUNNER_TEMP/notarize.zip"
  xcrun notarytool submit "$RUNNER_TEMP/notarize.zip" --key "$NOTARY_KEY_PATH" \
    --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER_ID" --wait \
    --output-format json > "$output/notarization.json"
  python3 - "$output/notarization.json" <<'PY'
import json, sys
result = json.load(open(sys.argv[1]))
if result.get('status') != 'Accepted':
    raise SystemExit(f"Notarization failed: {result}")
PY
  xcrun stapler staple "$app"
  xcrun stapler validate "$app"
  codesign --verify --deep --strict --verbose=2 "$app"
  spctl --assess --type execute --verbose=2 "$app"
fi
bash scripts/prepare-homebrew.sh "$app" "$output"
# Check the final ZIP, including signatures/ticket after its packaging round trip.
verify_dir=$(mktemp -d)
trap 'rm -rf "$verify_dir"' EXIT
ditto -x -k "$output/source-link-$version.zip" "$verify_dir"
"$verify_dir/source-link.app/Contents/Helpers/source-link" config validate examples/config.json
if [[ "$mode" == publish ]]; then
  codesign --verify --deep --strict "$verify_dir/source-link.app"
  xcrun stapler validate "$verify_dir/source-link.app"
fi
