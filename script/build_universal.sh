#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
SHENG_TARGET_ARCH=arm64 SHENG_BUILD_CONFIGURATION=release ./script/build_and_run.sh --build-only
SHENG_TARGET_ARCH=x86_64 SHENG_BUILD_CONFIGURATION=release ./script/build_and_run.sh --build-only
STAGING_ROOT="$(mktemp -d "$ROOT/dist/.sheng-universal.XXXXXX")"
trap 'rm -rf "$STAGING_ROOT"' EXIT
BUNDLE="$STAGING_ROOT/ShengJian.app"
mkdir -p "$BUNDLE"
cp -R dist/ShengJian-AppleSilicon.app/Contents "$BUNDLE/"
/usr/bin/lipo -create dist/ShengJian-AppleSilicon.app/Contents/MacOS/ShengJian dist/ShengJian-Intel.app/Contents/MacOS/ShengJian -output "$BUNDLE/Contents/MacOS/ShengJian"
source "$ROOT/script/signing_identity.sh"
IDENTITY="$(resolve_signing_identity)"
/usr/bin/codesign --force --sign "$IDENTITY" "$BUNDLE"
/usr/bin/codesign --verify --strict "$BUNDLE"
/usr/bin/lipo -info "$BUNDLE/Contents/MacOS/ShengJian"
source "$ROOT/script/publish_bundle.sh"
publish_bundle "$BUNDLE" "$ROOT/dist/ShengJian.app"
# Keep one obvious launch target; architecture bundles are internal build artifacts.
mkdir -p "$ROOT/.build/bundles"
publish_bundle "$ROOT/dist/ShengJian-AppleSilicon.app" "$ROOT/.build/bundles/ShengJian-AppleSilicon.app"
publish_bundle "$ROOT/dist/ShengJian-Intel.app" "$ROOT/.build/bundles/ShengJian-Intel.app"
