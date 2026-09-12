# Manual verification

1. Open Settings with `open .build/xcode/Build/Products/Debug/source-link.app --args --settings`. Close the window and run the command again to verify it reopens.
   Also verify Settings still opens from the menu-bar icon.
2. Open a `source-link:` URL for an unknown name and a file in your checkout.
3. Choose the repository root and Xcode; verify the requested file and line in Xcode.
4. Install VS Code and select it for `md`; open a Markdown link with a line and column.
5. Add a second checkout under the repository, make it default, and verify the same shared link opens there.
   Remove that checkout and verify the remaining checkout becomes default.
6. Switch among both Settings pages, add and remove extension rules, and verify each opens in its selected editor.
7. Change Settings, wait for “All changes saved”, restart the app and verify that mappings and editor rules persist.
8. Try an absent file, an escaping symlink, and an invalid line; verify a visible error and no editor launch.

9. Edit JSON externally and verify the app reloads within a second; repeat with an atomic file replacement.
10. Keep a UI draft open while changing an unrelated setting externally, then wait for auto-save and verify both survive.
11. Change the same setting externally and in a draft; verify auto-save reports a conflict and retains the draft.
12. Introduce invalid JSON; verify the error is visible and existing links use the last valid settings.
13. Symlink the config into dotfiles, auto-save a change, and verify the symlink remains intact.
14. With no configuration file, launch and verify defaults are used; save settings and verify the file is created.

Unit tests cover URL and JSON parsing, schema validation, JSON round-trips, conflicts,
symlink saves, path containment, worktree decisions, file-type routing, and editor
arguments. `make app-test` runs Swift Testing coverage for autosave cancellation, external-edit
merging, conflicts, invalid-file recovery, and duplicate-rule validation with a controlled save delay.
These app unit tests are also included in `make check`. Real editor navigation requires the manual checks above.


15. Create a configuration conflict, then choose **Discard changes and reload**. Verify the file’s settings appear and a subsequent edit saves successfully. Repeat with invalid JSON: the draft should remain until the file is repaired.
