#!/bin/sh
# Xcode Cloud selects the committed workspace, then generates its project here.
set -eu

if ! command -v xcodegen >/dev/null 2>&1; then
  HOMEBREW_NO_AUTO_UPDATE=1 brew install xcodegen
fi

repository_root="${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$repository_root/app"
xcodegen generate
