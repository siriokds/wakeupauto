#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
app="$PWD/build/WakeUpAuto.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp Sources/Info.plist "$app/Contents/Info.plist"
sdk="$(xcrun --sdk macosx --show-sdk-path)"
module_cache="$PWD/build/ModuleCache"
xcrun --sdk macosx swiftc -sdk "$sdk" -module-cache-path "$module_cache" \
    Sources/WiFiGlyph.swift tools/AppIcon/main.swift -o "$PWD/build/make-app-icon"
"$PWD/build/make-app-icon" "$app/Contents/Resources/WakeUpAuto.icns"
xcrun --sdk macosx swiftc -sdk "$sdk" -target "$(uname -m)-apple-macos27.0" \
    -module-cache-path "$module_cache" -O Sources/*.swift -o "$app/Contents/MacOS/WakeUpAuto"
codesign --force --sign - "$app"
printf '%s\n' "$app"
