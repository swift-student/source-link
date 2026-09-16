#!/bin/bash
set -euo pipefail
mkdir -p .tools/ci/bin
archive=$(mktemp)
trap 'rm -f "$archive"' EXIT
curl -fL --retry 3 https://github.com/nicklockwood/SwiftFormat/releases/download/0.63.0/swiftformat.zip -o "$archive"
echo "28c7802e11fa5ae113d903066439c6bb1be20a8ac1ad9709c42616a7e273fb0f  $archive" | shasum -a 256 -c -
unzip -p "$archive" swiftformat > .tools/ci/bin/swiftformat
chmod +x .tools/ci/bin/swiftformat
.tools/ci/bin/swiftformat --version
