#!/bin/bash
# Create a Homebrew release archive and cask from an already-built app.
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: bash scripts/prepare-homebrew.sh APP_BUNDLE OUTPUT_DIRECTORY" >&2
  exit 2
fi

app_bundle="$1"
output_dir="$2"
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
if [[ ! -x "$app_bundle/Contents/MacOS/source-link" || ! -x "$app_bundle/Contents/Helpers/source-link" ]]; then
  echo "The app must contain both the app executable and Contents/Helpers/source-link." >&2
  exit 1
fi
release_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app_bundle/Contents/Info.plist")
if [[ ! "$release_version" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]]; then
  echo "CFBundleShortVersionString must contain one to three numeric components." >&2
  exit 1
fi

staging_dir=$(mktemp -d "${TMPDIR:-/tmp}/source-link-homebrew.XXXXXX")
trap 'rm -rf "$staging_dir"' EXIT
mkdir -p "$output_dir"
ditto "$app_bundle" "$staging_dir/source-link.app"
archive="$output_dir/source-link-$release_version.zip"
ditto -c -k --sequesterRsrc --keepParent "$staging_dir/source-link.app" "$archive"
checksum=$(shasum -a 256 "$archive")
checksum=${checksum%% *}
sed -e "s/@VERSION@/$release_version/g" -e "s/@SHA256@/$checksum/g" \
  "$script_dir/../homebrew/source-link.rb.in" > "$output_dir/source-link.rb"
printf 'Created %s\nCreated %s\n' "$archive" "$output_dir/source-link.rb"
