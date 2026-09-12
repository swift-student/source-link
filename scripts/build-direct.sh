#!/bin/bash
# Standalone local build when Xcode's workspace/package services are unavailable.
set -euo pipefail
cd "$(dirname "$0")/.."
output_dir="$PWD/.build/direct"
mkdir -p "$output_dir/modules" "$output_dir/source-link.app/Contents/MacOS" "$output_dir/cache"
xcrun swiftc -swift-version 6 -parse-as-library -target arm64-apple-macos15.0 \
  -module-cache-path "$output_dir/cache" -emit-library -static -emit-module \
  -module-name SourceLinkCore -emit-module-path "$output_dir/modules/SourceLinkCore.swiftmodule" \
  Packages/SourceLinkPackage/Sources/SourceLinkCore/*.swift -o "$output_dir/modules/libSourceLinkCore.a"
xcrun swiftc -swift-version 6 -parse-as-library -target arm64-apple-macos15.0 \
  -module-cache-path "$output_dir/cache" -I "$output_dir/modules" -L "$output_dir/modules" \
  -lSourceLinkCore \
  app/Sources/SourceLinkApp/*.swift \
  -o "$output_dir/source-link.app/Contents/MacOS/source-link"
xcrun swiftc -swift-version 6 -target arm64-apple-macos15.0 \
  -module-cache-path "$output_dir/cache" -I "$output_dir/modules" -L "$output_dir/modules" \
  -lSourceLinkCore \
  Packages/SourceLinkPackage/Sources/SourceLinkCLI/main.swift -o "$output_dir/source-link"
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
