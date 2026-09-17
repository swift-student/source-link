#!/bin/bash
# Keep published release assets immutable; allow retries after a later tap failure.
set -euo pipefail
tag="v${RELEASE_VERSION:?}"
repo=${GITHUB_REPOSITORY:?}
archive="source-link-$RELEASE_VERSION.zip"
if gh release view "$tag" --repo "$repo" >/dev/null 2>&1; then
  draft=$(gh release view "$tag" --repo "$repo" --json isDraft --jq .isDraft)
  if [[ "$draft" != true ]]; then
    # A previous attempt already published. Use its cask and verify its archive.
    gh release download "$tag" --repo "$repo" --pattern source-link.rb --pattern "$archive" \
      --dir .build/release --clobber
  else
    gh release upload "$tag" .build/release/"$archive" .build/release/source-link.rb \
      .build/release/notarization.json --repo "$repo" --clobber
  fi
else
  gh release create "$tag" .build/release/"$archive" .build/release/source-link.rb \
    .build/release/notarization.json --repo "$repo" --verify-tag --draft --generate-notes --title "Source Link $RELEASE_VERSION"
fi
checksum=$(shasum -a 256 ".build/release/$archive")
checksum=${checksum%% *}
grep -q "sha256 \"$checksum\"" .build/release/source-link.rb
# Publishing precedes the tap update, so Homebrew never points at a draft asset.
gh release edit "$tag" --repo "$repo" --draft=false
curl --fail --location --retry 3 "https://github.com/$repo/releases/download/$tag/$archive" \
  --output "$RUNNER_TEMP/public-release.zip"
echo "$checksum  $RUNNER_TEMP/public-release.zip" | shasum -a 256 -c -
