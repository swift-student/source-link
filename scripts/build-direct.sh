#!/bin/bash
# Standalone local build when Xcode's workspace/package services are unavailable.
set -euo pipefail
cd "$(dirname "$0")/.."
output_dir="$PWD/.build/direct"
mkdir -p "$output_dir/modules" "$output_dir/source-link.app/Contents/MacOS" "$output_dir/cache"
xcrun clang++ -std=c++17 -target arm64-apple-macos15.0 -I Sources/CTOML/include \
  -c Sources/CTOML/Bridge.cpp -o "$output_dir/modules/Bridge.o"
xcrun swiftc -swift-version 6 -parse-as-library -target arm64-apple-macos15.0 \
  -module-cache-path "$output_dir/cache" -emit-library -static -emit-module \
  -module-name XedLinkCore -emit-module-path "$output_dir/modules/XedLinkCore.swiftmodule" \
  -I Sources/CTOML/include Sources/XedLinkCore/*.swift -o "$output_dir/modules/libXedLinkCore.a"
xcrun swiftc -swift-version 6 -parse-as-library -target arm64-apple-macos15.0 \
  -module-cache-path "$output_dir/cache" -I "$output_dir/modules" -L "$output_dir/modules" \
  -I Sources/CTOML/include -lXedLinkCore -lc++ "$output_dir/modules/Bridge.o" \
  app/Sources/XedLinkApp/*.swift \
  -o "$output_dir/source-link.app/Contents/MacOS/source-link"
xcrun swiftc -swift-version 6 -target arm64-apple-macos15.0 \
  -module-cache-path "$output_dir/cache" -I "$output_dir/modules" -L "$output_dir/modules" \
  -I Sources/CTOML/include -lXedLinkCore -lc++ "$output_dir/modules/Bridge.o" \
  Sources/SourceLinkCLI/main.swift -o "$output_dir/source-link"
python3 - "$output_dir/source-link.app/Contents/Info.plist" <<'PY'
import plistlib
import sys
from pathlib import Path
info = {
    'CFBundleExecutable': 'source-link',
    'CFBundleIdentifier': 'com.shawngee.XedLink',
    'CFBundleName': 'source-link',
    'CFBundleDisplayName': 'Source Link',
    'CFBundlePackageType': 'APPL',
    'CFBundleVersion': '1',
    'CFBundleShortVersionString': '1.0',
    'LSMinimumSystemVersion': '15.0',
    'LSUIElement': True,
    'CFBundleURLTypes': [{
        'CFBundleTypeRole': 'Editor',
        'CFBundleURLName': 'com.shawngee.XedLink.xed',
        'CFBundleURLSchemes': ['xed', 'source-link'],
    }],
}
Path(sys.argv[1]).write_bytes(plistlib.dumps(info))
PY
codesign --force --sign - "$output_dir/source-link.app"
