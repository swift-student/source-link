# Release Source Link

Releases run on standard GitHub-hosted macOS runners. Push a version tag to build
both architectures, sign with Developer ID, notarize and staple, publish a GitHub
release, and update `swift-student/homebrew-tap`. No personal runner or Xcode Cloud
build is required. CI and Pages also use GitHub-hosted runners. Both source
repositories are public, so package resolution needs no deploy key.

## One-time Apple credentials

Use team **94ZMA2MYR4**. The app bundle ID is **com.shawngee.SourceLink**.
Add secrets to [Source Link's Actions secrets](https://github.com/swift-student/source-link/settings/secrets/actions),
not to source control, an issue, or a chat.

### Developer ID certificate

1. In Xcode's Apple account settings, select your team and **Manage Certificates**.
   Create a **Developer ID Application** certificate (not Apple Development or Mac
   App Distribution). If unavailable there, create it through the Apple Developer
   Certificates portal using a certificate signing request from Keychain Access.
2. In Keychain Access, select **My Certificates**, locate that Developer ID
   Application identity, and confirm it expands to show its private key.
3. Export the identity and its private key as a password-protected `.p12` file.
   A `.cer` file alone is insufficient. Xcode Cloud's managed certificate does not
   automatically provide an exportable local private key.
4. Store the export and password directly in GitHub secrets. With GitHub CLI on
   that Mac (substitute your own file path):

   ```sh
   base64 -i /path/to/DeveloperID.p12 | gh secret set APPLE_CERTIFICATE_P12_BASE64 --repo swift-student/source-link
   gh secret set APPLE_CERTIFICATE_PASSWORD --repo swift-student/source-link
   ```

   The second command prompts for the export password without putting it in shell
   history. Keep your original identity backed up securely.

### Notarization API key

1. Open **App Store Connect → Users and Access → Integrations → App Store Connect API**.
   Request API access if your team has not enabled it.
2. Generate a **team API key** with the Developer role (or another role authorized
   for notarization). Download its `.p8` private key; Apple only allows downloading
   it once. Record its Key ID and the team's Issuer ID.
3. Add the following secrets:

   ```sh
   gh secret set NOTARY_KEY_P8 --repo swift-student/source-link < /path/to/AuthKey_KEYID.p8
   gh secret set NOTARY_KEY_ID --repo swift-student/source-link
   gh secret set NOTARY_ISSUER_ID --repo swift-student/source-link
   ```

This workflow uses a team key with an issuer; individual API keys require different
notarytool arguments and are not configured here. Accept any pending Apple developer
agreements in your account before releasing.

### Homebrew publishing

The public tap is `swift-student/homebrew-tap`. The source repository's
`HOMEBREW_TAP_DEPLOY_KEY` secret holds an SSH deploy key with write access only to
that tap. This is separate from the automatic `GITHUB_TOKEN`, which publishes
releases in `source-link`. The tap credential is configured during pipeline setup.

## Validate without signing

In **Actions → Release → Run workflow**, keep **dry_run** selected and choose a
three-part version, for example `1.0.0`. This runs `make check`, builds universal
executables, checks the embedded CLI, and verifies the ZIP packaging round trip.
The `unsigned-release-dry-run` artifact is for testing, not distribution. No Apple
credentials are needed and neither GitHub Releases nor the tap is modified.

## Publish a version

After CI passes on main and all five Apple secrets are installed:

```sh
git switch main
git pull --ff-only
git tag v1.0.0
git push origin v1.0.0
```

Use a new `vX.Y.Z` tag for each release. The workflow derives the app's marketing
version from the tag and its build number from the workflow run number; no manual
Info.plist edit is needed. It rejects publishing from a branch or from a commit
outside main's history. Never move a published tag.

The job verifies both `arm64` and `x86_64`, signs the embedded helper and app with
hardened runtime, waits for Apple's acceptance, staples the ticket, and verifies
Gatekeeper and the packaged app. Only then does it publish the ZIP and cask, check
an anonymous download against its checksum, and update the tap.

If the tap step fails after publication, rerun the failed workflow. It retrieves
and verifies the existing release assets instead of replacing a published ZIP.
Check the run logs before retrying a rejected notarization submission.

Install a published release with:

```sh
brew install --cask swift-student/tap/source-link
```

The first signed release still needs an actual Homebrew installation check before
it is announced. `make release` remains a local, ad-hoc packaging command and does
not publish or notarize anything.

## Existing Xcode Cloud setup

The committed workspace and `ci_scripts/ci_post_clone.sh` remain compatible with
Xcode Cloud. It is optional and not part of this publishing pipeline. Disable its
automatic triggers in Xcode Cloud if you do not want duplicate builds.

## References

- [GitHub: installing an Apple certificate on a hosted runner](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications)
- [Apple: Developer ID signing](https://developer.apple.com/developer-id/)
- [Apple: customizing notarization](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)
- [Homebrew: create and maintain a tap](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap)
