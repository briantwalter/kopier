#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")"
./Scripts/FetchSparkle.sh
mkdir -p Kopier.app/Contents/MacOS Kopier.app/Contents/Resources Kopier.app/Contents/Frameworks
rm -rf Kopier.app/Contents/Frameworks/Sparkle.framework
ditto .build/Sparkle/Sparkle.framework Kopier.app/Contents/Frameworks/Sparkle.framework
swift -module-cache-path /private/tmp/kopier-module-cache Scripts/MakeIcon.swift
iconutil -c icns Assets/Kopier.iconset -o Kopier.app/Contents/Resources/Kopier.icns
cp Assets/MenuIcon.png Kopier.app/Contents/Resources/MenuIcon.png
swiftc -target "$(uname -m)-apple-macos13.0" -module-cache-path /private/tmp/kopier-module-cache Source/*.swift -o Kopier.app/Contents/MacOS/Kopier -framework AppKit -F .build/Sparkle -framework Sparkle -Xlinker -rpath -Xlinker @executable_path/../Frameworks
cat > Kopier.app/Contents/Info.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Kopier</string>
<key>CFBundleIdentifier</key><string>local.kopier.app</string>
<key>CFBundleName</key><string>Kopier</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>SUEnableAutomaticChecks</key><false/>
<key>SUAllowsAutomaticUpdates</key><false/>
<key>SUEnableSystemProfiling</key><false/>
<key>SUVerifyUpdateBeforeExtraction</key><true/>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>CFBundleIconFile</key><string>Kopier</string>
<key>LSUIElement</key><false/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
for key in CFBundleShortVersionString CFBundleVersion KopierReleaseDate SUFeedURL SUPublicEDKey; do
    value=$(/usr/libexec/PlistBuddy -c "Print :$key" ReleaseConfig.plist)
    /usr/libexec/PlistBuddy -c "Add :$key string $value" Kopier.app/Contents/Info.plist
done
# Preserve Sparkle’s upstream signatures on its framework and helper tools.
codesign --force --sign - Kopier.app
