#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
# D2 0.9.0. Override D2 with a path to the executable if it is not on PATH.
for name in source-link click-dispatch click-parameters; do
  "${D2:-d2}" --layout elk --elk-nodeNodeBetweenLayers 35 --pad 30 "$name.d2" "$name.svg"
done
