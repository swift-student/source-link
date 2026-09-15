#!/bin/bash
# Standalone local build when Xcode's workspace/package services are unavailable.
set -euo pipefail
cd "$(dirname "$0")/.."
output_dir="$PWD/.build/direct"
mkdir -p "$output_dir/modules" "$output_dir/source-link.app/Contents/MacOS" "$output_dir/cache"
# SwiftPM links SourceSymbols and its bundled parsers into the static library.
swift build --package-path Packages/SourceLinkPackage --build-system native --product SourceLinkCore
package_bin="$(swift build --package-path Packages/SourceLinkPackage --build-system native --show-bin-path)"
cp "$package_bin/libSourceLinkCore.a" "$output_dir/modules/"
mkdir -p "$output_dir/source-link.app/Contents/Resources"
cp -R "$package_bin/SourceLinkPackage_SourceLinkCore.bundle" "$output_dir/source-link.app/Contents/Resources/"
cp -R "$package_bin/SourceLinkPackage_SourceLinkCore.bundle" "$output_dir/"
dependency_flags=(
  -I "$package_bin/Modules"
  -Xcc "-fmodule-map-file=$package_bin/TreeSitter.build/module.modulemap"
  -Xcc "-fmodule-map-file=$package_bin/TreeSitterSwiftGrammar.build/module.modulemap"
  -Xcc "-fmodule-map-file=$package_bin/TreeSitterRubyGrammar.build/module.modulemap"
)
xcrun swiftc -swift-version 6 -parse-as-library -target arm64-apple-macos15.0 \
  -module-cache-path "$output_dir/cache" -L "$output_dir/modules" \
  "${dependency_flags[@]}" -lSourceLinkCore \
  app/Sources/SourceLinkApp/*.swift \
  -o "$output_dir/source-link.app/Contents/MacOS/source-link"
xcrun swiftc -swift-version 6 -target arm64-apple-macos15.0 \
  -module-cache-path "$output_dir/cache" -L "$output_dir/modules" \
  "${dependency_flags[@]}" -lSourceLinkCore \
  Packages/SourceLinkPackage/Sources/SourceLinkCLI/*.swift -o "$output_dir/source-link"
mkdir -p "$output_dir/source-link.app/Contents/Helpers"
cp "$output_dir/source-link" "$output_dir/source-link.app/Contents/Helpers/source-link"
codesign --force --sign - "$output_dir/source-link.app/Contents/Helpers/source-link"
mkdir -p "$output_dir/source-link.app/Contents/Resources"
xcrun actool app/Sources/SourceLinkApp/Assets.xcassets \
  --compile "$output_dir/source-link.app/Contents/Resources" \
  --platform macosx --minimum-deployment-target 15.0 --target-device mac \
  --app-icon AppIcon --output-partial-info-plist "$output_dir/asset-info.plist"
python3 - "$output_dir/source-link.app/Contents/Info.plist" "$output_dir/asset-info.plist" <<'PY'
import plistlib
import sys
from pathlib import Path
info = {
    'CFBundleExecutable': 'source-link',
    'CFBundleIdentifier': 'com.shawngee.SourceLink',
    'CFBundleName': 'source-link',
    'CFBundleDisplayName': 'Source Link',
    'CFBundlePackageType': 'APPL',
    'CFBundleVersion': '1',
    'CFBundleShortVersionString': '1.0',
    'LSMinimumSystemVersion': '15.0',
    'LSUIElement': True,
    'CFBundleURLTypes': [{
        'CFBundleTypeRole': 'Editor',
        'CFBundleURLName': 'com.shawngee.SourceLink.source-link',
        'CFBundleURLSchemes': ['source-link'],
    }],
}
info.update(plistlib.loads(Path(sys.argv[2]).read_bytes()))
Path(sys.argv[1]).write_bytes(plistlib.dumps(info))
PY
mkdir -p "$output_dir/source-link.app/Contents/Resources"
cp Packages/SourceLinkPackage/Sources/SourceLinkCore/Resources/editors.json "$output_dir/source-link.app/Contents/Resources/editors.json"
cp Packages/SourceLinkPackage/Sources/SourceLinkCore/Resources/editors.json "$output_dir/editors.json"
codesign --force --sign - "$output_dir/source-link.app"
