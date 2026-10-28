#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
version=2.10.1
checksum=1a856d2a9edb8e628de88121d7be04cf0e2167f8641650b78fca00b14244cf27
if [[ -f .build/Sparkle/.version && "$(cat .build/Sparkle/.version)" == "$version" ]]; then
    exit 0
fi
mkdir -p .build
archive="$(mktemp /private/tmp/kopier-sparkle.XXXXXX)"
trap 'rm -f "$archive"' EXIT
curl --fail --location --silent --show-error "https://github.com/sparkle-project/Sparkle/releases/download/$version/Sparkle-$version.tar.xz" -o "$archive"
print -r -- "$checksum  $archive" | shasum -a 256 -c -
rm -rf .build/Sparkle
mkdir -p .build/Sparkle
tar -xf "$archive" -C .build/Sparkle
print -r -- "$version" > .build/Sparkle/.version
