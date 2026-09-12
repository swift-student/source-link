# Repository instructions

- Use Swift 6 and Swift Testing.
- Keep URL parsing and process invocation independent of the app UI.
- Keep the app a menu-bar utility with no Dock icon; allow Settings and first-link setup windows.
- Run `make check` before submitting changes.
- For visual changes, attach screenshots to the pull request description using GitHub CLI 2.99.0 or newer: `gh pr edit <number> --body-file <markdown-file> --attach <image-path>`. Reference the same local image paths in the Markdown body so the CLI replaces them with uploaded image URLs. Keep snapshot baselines in Git LFS; use these attachments for visual review on GitHub.
