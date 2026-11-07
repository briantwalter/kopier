#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")"
case "${1:-}" in
    "") app_name="Kopier-dev"; bundle_id="local.kopier.dev" ;;
    --release) app_name="Kopier"; bundle_id="local.kopier.app" ;;
    *) print -u2 "Usage: ./build.sh [--release]"; exit 1 ;;
esac
app_bundle="$app_name.app"
./Scripts/FetchSparkle.sh
mkdir -p "$app_bundle"/Contents/MacOS "$app_bundle"/Contents/Resources "$app_bundle"/Contents/Frameworks
rm -rf "$app_bundle"/Contents/Frameworks/Sparkle.framework
ditto .build/Sparkle/Sparkle.framework "$app_bundle"/Contents/Frameworks/Sparkle.framework
swift -module-cache-path /private/tmp/kopier-module-cache Scripts/MakeIcon.swift
iconutil -c icns Assets/Kopier.iconset -o "$app_bundle"/Contents/Resources/Kopier.icns
cp Assets/MenuIcon.png "$app_bundle"/Contents/Resources/MenuIcon.png
mkdir -p "$app_bundle"/Contents/Resources/Keyboard
cp Assets/Keyboard/Key-*.wav "$app_bundle"/Contents/Resources/Keyboard/
cp Assets/Keyboard/README.md "$app_bundle"/Contents/Resources/Keyboard/Credits.md
swiftc -target "$(uname -m)-apple-macos13.0" -module-cache-path /private/tmp/kopier-module-cache Source/*.swift -o "$app_bundle"/Contents/MacOS/Kopier -framework AppKit -F .build/Sparkle -framework Sparkle -Xlinker -rpath -Xlinker @executable_path/../Frameworks
cat > "$app_bundle"/Contents/Info.plist <<'PLIST'
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
/usr/libexec/PlistBuddy -c "Set :CFBundleName $app_name" "$app_bundle"/Contents/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $bundle_id" "$app_bundle"/Contents/Info.plist
for key in CFBundleShortVersionString CFBundleVersion KopierReleaseDate SUFeedURL SUPublicEDKey; do
    if [[ "$app_name" == "Kopier-dev" && "$key" == "SUFeedURL" ]]; then
        continue
    fi
    value=$(/usr/libexec/PlistBuddy -c "Print :$key" ReleaseConfig.plist)
    /usr/libexec/PlistBuddy -c "Add :$key string $value" "$app_bundle"/Contents/Info.plist
done
# Preserve Sparkle’s upstream signatures on its framework and helper tools.
codesign --force --sign "${KOPIER_SIGNING_IDENTITY:--}" "$app_bundle"
