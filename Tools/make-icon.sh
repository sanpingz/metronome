#!/bin/sh
# Regenerates HoppyBeat/Assets.xcassets/AppIcon.appiconset/AppIcon.png
set -e
cd "$(dirname "$0")/.."
BIN="$(mktemp -d)/make-icon"
swiftc -parse-as-library -O Tools/MakeIcon.swift HoppyBeat/Views/Theme.swift HoppyBeat/Views/FrogView.swift -o "$BIN"
"$BIN" HoppyBeat/Assets.xcassets/AppIcon.appiconset/AppIcon.png
