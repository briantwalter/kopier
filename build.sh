#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p Kopier.app/Contents/MacOS Kopier.app/Contents/Resources
swift -module-cache-path /private/tmp/kopier-module-cache Scripts/MakeIcon.swift
iconutil -c icns Assets/Kopier.iconset -o Kopier.app/Contents/Resources/Kopier.icns
cp Assets/MenuIcon.png Kopier.app/Contents/Resources/MenuIcon.png
swiftc -module-cache-path /private/tmp/kopier-module-cache Source/*.swift -o Kopier.app/Contents/MacOS/Kopier -framework AppKit
cat > Kopier.app/Contents/Info.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Kopier</string>
<key>CFBundleIdentifier</key><string>local.kopier.app</string>
<key>CFBundleName</key><string>Kopier</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>CFBundleIconFile</key><string>Kopier</string>
<key>LSUIElement</key><false/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - Kopier.app
