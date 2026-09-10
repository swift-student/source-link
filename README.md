# xed-link

A macOS menu-bar app for opening `xed:` source links in Xcode. It owns the custom URL scheme
as an accessory application, so source links do not foreground DevCtrl or create an ordinary
window or Dock icon.

## URL format

```text
xed:///absolute/path/to/File.swift?line=42&project=/absolute/path/to/Project.xcworkspace
```

- `line` is optional and must be a positive integer.
- `project` is optional and may identify an Xcode project, workspace, or Swift package.
- Paths must be absolute. URL-encode spaces and other reserved characters.

The app forwards validated links to:

```text
/usr/bin/xed --project <project> --line <line> <file>
```

## Development

Install [XcodeGen](https://github.com/yonaskolb/XcodeGen) and
[SwiftLint](https://github.com/realm/SwiftLint), then run:

```sh
make check
```

Open `XedLink.xcworkspace`, not the generated Xcode project.

To build and register the app with Launch Services:

```sh
make run
```

Then test a link:

```sh
open 'xed:///tmp/Example.swift?line=1'
```
