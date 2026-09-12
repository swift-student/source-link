# Troubleshooting

## Settings or links do not open

Launch the built app at least once, then use its menu-bar icon to open Settings. To open Settings directly:

```sh
open .build/xcode/Build/Products/Debug/source-link.app --args --settings
```

A repository name maps to a local root folder. Check the mapping and default checkout in Settings. The linked file must exist under that root; escaping symlinks and traversal paths are rejected. See [usage](usage.md).

## An editor fails to launch

Install the editor separately and choose **Edit Configuration…** in **Editors** to check its executable and argument templates. The built-in Xcode profile uses `/usr/bin/xed`; other editor profiles specify their CLI executable. A nonzero editor exit status is reported as a launch failure. Xcode receives the line but not the column.

## A settings error appears

Autosave runs quietly after 500 ms without edits. If an error occurs, an alert appears once; repeated background checks do not reopen it. Choose **Keep Editing** to retain your draft. Duplicate extension rules must be removed before settings can save.

For a conflict with an external edit, either adjust the conflicting setting to match the file or choose **Reload from File** in the alert. This cancels pending saves and loads the current file without writing it. A removed file loads defaults; it is only recreated by a later edit. A changed symlink is followed at its current destination.

If the file is invalid, reload reports the error and keeps your draft and the last valid active settings. Repair the JSON, then continue editing, or use **Reload from File** if another error alert appears. The background watcher can resume pending edits after a repaired file becomes valid; the alert’s reload action explicitly accepts the file’s contents.

## Check the configuration

```sh
swift run source-link config path
swift run source-link config validate
```

Finder-launched apps may use a different environment from your terminal. The default path is `~/.config/source-link/config.json`. See [configuration](configuration.md) for `XDG_CONFIG_HOME`, symlinks, and validation details.
