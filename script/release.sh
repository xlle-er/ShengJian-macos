#!/usr/bin/env bash
# Builds the Universal release, packs it as dist/release/ShengJian-<version>.zip and signs the
# archive for the in-app updater. Pass --publish to also create the GitHub Release.
#
#   ./script/release.sh            build, zip and sign
#   ./script/release.sh --publish  also run `gh release create v<version>` with notes from RELEASE_NOTES.md
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
VERSION="$(tr -d '[:space:]' < VERSION)"
OUT="$ROOT/dist/release"
ARCHIVE="$OUT/ShengJian-$VERSION.zip"
# Releases are ad-hoc signed (no personal certificate data in the shipped app).
export SHENG_CODESIGN_IDENTITY=-
# Keep local paths (home folder, checkout location) out of the shipped binary.
export RUSTFLAGS="${RUSTFLAGS:-} --remap-path-prefix=$HOME=/home --remap-path-prefix=$ROOT=/src"
export CFLAGS="${CFLAGS:-} -ffile-prefix-map=$ROOT=/src -ffile-prefix-map=$HOME=/home"
./script/build_universal.sh
/usr/bin/codesign --verify --deep --strict dist/ShengJian.app
if /usr/bin/strings dist/ShengJian.app/Contents/MacOS/ShengJian | /usr/bin/grep -q "$HOME"; then
  echo "The binary still contains local paths; not packaging." >&2; exit 1
fi
mkdir -p "$OUT"
rm -f "$ARCHIVE" "$ARCHIVE.sig"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent dist/ShengJian.app "$ARCHIVE"
swift script/update_signing.swift sign "$ARCHIVE" >/dev/null
shasum -a 256 "$ARCHIVE"
if [ "${1:-}" = --publish ]; then
  [ -f RELEASE_NOTES.md ] || { echo "Write RELEASE_NOTES.md first." >&2; exit 1; }
  gh release create "v$VERSION" "$ARCHIVE" "$ARCHIVE.sig" --repo xlle-er/ShengJian-macos --title "声笺 $VERSION" --notes-file RELEASE_NOTES.md
fi
