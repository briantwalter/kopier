#!/bin/zsh
# Prepare only; this script never publishes to GitHub.
set -euo pipefail
cd "$(dirname "$0")/.."
tag="${1:?Usage: Scripts/PrepareRelease.sh TAG (for example v0.2-beta)}"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' ReleaseConfig.plist)
[[ "$tag" == "v$version" ]] || { print -u2 'Tag must match v + the version in ReleaseConfig.plist'; exit 1; }
./build.sh --release
codesign --verify --deep --strict Kopier.app
mkdir -p releases
previous_appcast="$(mktemp /private/tmp/kopier-appcast.XXXXXX)"
trap 'rm -f "$previous_appcast"' EXIT
if [[ -f releases/appcast.xml ]]; then
    cp releases/appcast.xml "$previous_appcast"
fi
architecture="$(uname -m)"
archive="releases/Kopier-$version-macos-$architecture.zip"
[[ ! -e "$archive" ]] || { print -u2 "Archive already exists: $archive. Never replace a published build."; exit 1; }
ditto -c -k --sequesterRsrc --keepParent Kopier.app "$archive"
# Keep previous archives and the prior appcast in releases/. Sparkle generates
# incremental patches and retains each older item's original download URL.
.build/Sparkle/bin/generate_appcast --account local.kopier.app \
    --download-url-prefix "https://github.com/briantwalter/kopier/releases/download/$tag/" \
    --embed-release-notes releases
# generate_appcast applies the new URL prefix to older archives too. Restore
# already-published URLs so older feed items keep pointing to their own release.
python3 - "$previous_appcast" releases/appcast.xml <<'PYTHON'
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from urllib.parse import urlparse

previous, current = map(Path, sys.argv[1:])
if previous.stat().st_size:
    old_urls = {
        Path(urlparse(node.attrib["url"]).path).name: node.attrib["url"]
        for node in ET.parse(previous).iter("enclosure")
    }
    text = current.read_text()
    for node in ET.parse(current).iter("enclosure"):
        url = node.attrib["url"]
        old = old_urls.get(Path(urlparse(url).path).name)
        if old and old != url:
            text = text.replace(url, old)
    current.write_text(text)
PYTHON
print 'Prepared releases/appcast.xml, signed archive, and any eligible delta patches.'
print 'Upload the new archive, appcast.xml, and newly generated .delta files to the matching GitHub release.'
