# Release Source Link with Xcode Cloud

Xcode Cloud builds and signs the app with Developer ID, then notarizes it using its
Notarize post-action. Publishing the resulting app to GitHub and updating the Homebrew
cask are separate steps. No signing certificate export or runner Keychain setup is
needed for this workflow.

## Connect the project once

1. On a Mac with Xcode, sign into your renewed Apple Developer account under
   **Xcode > Settings > Apple Accounts**. Accept any pending developer agreements.
2. Pull the latest repository, run `make generate`, and open `SourceLink.xcworkspace`. Select the
   **SourceLink** app scheme. The bundle identifier is `com.shawngee.SourceLink`.
3. Open **Report navigator > Cloud > Get Started**. Select the Source Link app and
   developer team **94ZMA2MYR4**. Automatic Release signing and that Team ID are
   configured in `app/project.yml`. Change team settings there so `make generate`
   preserves them; the Team ID is not a secret.
4. Grant Xcode Cloud GitHub access to both `swift-student/source-link` and its private
   Swift package dependency, `swift-student/swift-source-symbols`. Other package
   dependencies are public. If prompted later, use **Manage Repositories** to authorize
   the additional private dependency.
5. Allow Xcode to create an App Store Connect record if one does not exist. Use the
   macOS platform, the existing bundle identifier, a primary language, and a unique
   SKU such as `source-link-macos`. Creating the record does not publish an App Store listing.

The workspace and `ci_scripts/ci_post_clone.sh` are committed. Select the workspace
when configuring Xcode Cloud so it finds the hook beside it. The post-clone hook
installs XcodeGen if needed, then generates the project, shared schemes, and app
Info.plist before the build. Generated files remain ignored. For initial onboarding,
run `make generate` locally so Xcode can discover the app and scheme.

Keep workspace paths, the generated project path, and the SourceLink scheme name
stable. Apple cautions that dynamically generated projects can cause discovery and
build failures; the first cloud build must verify hook discovery and generation in
Apple's environment. A local generation/archive check alone does not verify cloud onboarding.

## Configure the release workflow

- Name: **Homebrew Release**.
- Source: `main`; start manually for the first release. For later releases, a `v*`
  tag start condition can limit this workflow to tagged versions.
- Environment: a released Xcode version with Swift 6.2 or newer.
- Action: **Archive**, macOS, scheme **SourceLink**, configuration **Release**, with
  **Developer ID** distribution.
- Post-action: **Notarize** for that archive. Use your Account Holder or another role
  authorized to configure notarization.

Release settings enable hardened runtime and build both Apple Silicon and Intel.
The archive embeds the `source-link` CLI at `Contents/Helpers/source-link`; it must
remain inside the app during signing and notarization.

Start a build and wait for both Archive and Notarize to succeed. From the completed
Notarize post-action, choose **Download Notarized App**. Use this output for publishing,
not the unsigned archive or the ad-hoc app created by `make release`.

## Prepare the Homebrew download

Extract the downloaded notarized app, then verify it and prepare the release files:

```sh
codesign --verify --deep --strict --verbose=2 /path/to/source-link.app
xcrun stapler validate /path/to/source-link.app
spctl --assess --type execute --verbose=2 /path/to/source-link.app
lipo -archs /path/to/source-link.app/Contents/MacOS/source-link
lipo -archs /path/to/source-link.app/Contents/Helpers/source-link
/path/to/source-link.app/Contents/Helpers/source-link --help
bash scripts/prepare-homebrew.sh /path/to/source-link.app .build/release
```

Both executables should include `arm64` and `x86_64`. The packaging script preserves
the signature and stapled ticket and computes a checksum for the final ZIP. Do not
modify the app after notarization or the ZIP after generating its checksum.

The cask template currently points to releases in `swift-student/source-link`. If that
repository is private, anonymous Homebrew users cannot download its release assets.
Choose a public release repository (which can contain only binaries and the cask),
update the template's download URL to that repository, and regenerate the cask before
publishing. Source code can remain private.

Upload `source-link-VERSION.zip` under release tag `vVERSION` in the selected public
repository. Publish the generated `source-link.rb` under `Casks/` in a public
`homebrew-...` tap. Verify an anonymous download matches the cask's SHA-256 checksum
and test a Homebrew installation before announcing the release.

For later releases, update `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in
`app/project.yml`, run `make generate` and `make check`, and commit the project changes
before starting the release workflow.

## References

- [Apple: Xcode Cloud project requirements](https://developer.apple.com/documentation/xcode/setting-up-your-project-to-use-xcode-cloud)
- [Apple: configure your first workflow](https://developer.apple.com/documentation/xcode/configuring-your-first-xcode-cloud-workflow)
- [Apple: private package dependencies](https://developer.apple.com/documentation/xcode/making-dependencies-available-to-xcode-cloud)
- [Apple: automatic notarization](https://developer.apple.com/videos/play/wwdc2023/10224/?time=753)
- [Homebrew: create and maintain a tap](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap)
