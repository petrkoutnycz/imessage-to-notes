#!/bin/bash
# Builds build/ImessageToNotes.app and signs it with the Apple Development certificate.
# Full Disk Access is tied to the signature, so every build must use the same certificate (ADR 0002).
set -euo pipefail

cd "$(dirname "$0")/.."
identity="${SIGNING_IDENTITY:-D04505537D8C20878625D1F7F05E10B8EAD68CFE}"
app="build/ImessageToNotes.app"

swift build -c release --product imessage-to-notes
binary="$(swift build -c release --show-bin-path)/imessage-to-notes"

mkdir -p "$app/Contents/MacOS"
cp App/Info.plist "$app/Contents/Info.plist"
cp "$binary" "$app/Contents/MacOS/imessage-to-notes"
codesign --force --sign "$identity" --timestamp=none "$app"
codesign --verify --strict --verbose=1 "$app"
echo "Built $app"
