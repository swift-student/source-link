# Release Source Link

After CI passes on `main`, push a new `vX.Y.Z` tag. For example:

```sh
git switch main
git pull --ff-only
git tag v0.0.2
git push origin v0.0.2
```

The [Release workflow](https://github.com/swift-student/source-link/actions/workflows/release.yml)
runs the checks, builds for Apple Silicon and Intel, signs and notarizes the app,
publishes a [GitHub release](https://github.com/swift-student/source-link/releases),
and updates the [Homebrew tap](https://github.com/swift-student/homebrew-tap).
The tag supplies the app version; no Info.plist edit is needed.
Use a new version for each release and never move a published tag.

## Check or retry a release

For a packaging check without publishing, choose **Run workflow** in Actions,
leave **dry_run** selected, and enter a version. The uploaded artifact is unsigned
and is only for testing. `make release` provides a local packaging check.

For a failed release, inspect the failed step before rerunning it. If publication
succeeded but the tap update failed, rerunning reuses the published assets without
replacing the ZIP or changing its checksum.

Signing credentials are already configured in
[Actions secrets](https://github.com/swift-student/source-link/settings/secrets/actions).
Update them there if a certificate or API key expires or is revoked.

## Install

```sh
brew install --cask swift-student/tap/source-link
# For an existing installation:
brew upgrade --cask swift-student/tap/source-link
```
