#!/bin/zsh
# Prepare only; this script never publishes to GitHub.
set -euo pipefail
cd "$(dirname "$0")/.."
tag="${1:?Usage: Scripts/PrepareRelease.sh TAG (for example v0.2-beta)}"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' ReleaseConfig.plist)
[[ "$tag" == "v$version" ]] || { print -u2 'Tag must match v + the version in ReleaseConfig.plist'; exit 1; }
./build.sh
codesign --verify --deep --strict Kopier.app
mkdir -p releases
architecture="$(uname -m)"
archive="releases/Kopier-$version-macos-$architecture.zip"
[[ ! -e "$archive" ]] || { print -u2 "Archive already exists: $archive. Never replace a published build."; exit 1; }
ditto -c -k --sequesterRsrc --keepParent Kopier.app "$archive"
# Keep previous archives and the prior appcast in releases/. Sparkle generates
# incremental patches and retains each older item's original download URL.
.build/Sparkle/bin/generate_appcast --account local.kopier.app \
    --download-url-prefix "https://github.com/briantwalter/kopier/releases/download/$tag/" \
    --embed-release-notes releases
print 'Prepared releases/appcast.xml, signed archive, and any eligible delta patches.'
print 'Upload the new archive, appcast.xml, and newly generated .delta files to the matching GitHub release.'
