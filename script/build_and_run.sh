#!/usr/bin/env bash
set -euo pipefail
MODE="${1:-run}"
case "$MODE" in run|--build-only|--verify|--debug|--logs|--telemetry) ;; *) echo "usage: $0 [run|--build-only|--verify|--debug|--logs|--telemetry]" >&2; exit 2;; esac
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
APP_NAME="ShengJian"
BUNDLE_ID="app.xlle.shengjian"
SDK_DIR="$ROOT_DIR/Vendor/SharedKit"
if [ ! -f "$SDK_DIR/Package.swift" ]; then echo "Initialize submodules: git submodule update --init --recursive" >&2; exit 1; fi
export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$CLANG_MODULE_CACHE_PATH"
if [ "$MODE" != --build-only ] && /usr/bin/pgrep -x "$APP_NAME" >/dev/null; then
  /usr/bin/pkill -TERM -x "$APP_NAME"
  for attempt in {1..150}; do
    if ! /usr/bin/pgrep -x "$APP_NAME" >/dev/null; then break; fi
    sleep 0.1
  done
  if /usr/bin/pgrep -x "$APP_NAME" >/dev/null; then echo "App is still finishing its session. Quit it before rebuilding." >&2; exit 1; fi
fi
BUILD_CONFIGURATION="${SHENG_BUILD_CONFIGURATION:-release}"
case "$BUILD_CONFIGURATION" in debug) export SHENG_ENGINE_PROFILE=debug;; release) export SHENG_ENGINE_PROFILE=release;; *) echo "Use debug or release." >&2;exit 2;; esac
TARGET_ARCH="${SHENG_TARGET_ARCH:-native}"
RUST_TARGET=""
SWIFT_TRIPLE=""
ARCH_SUFFIX=""
SCRATCH_PATH=.build/native
case "$TARGET_ARCH" in
 native) ;;
 x86_64) RUST_TARGET=x86_64-apple-darwin; SWIFT_TRIPLE=x86_64-apple-macosx13.0; ARCH_SUFFIX=-Intel ;;
 arm64) RUST_TARGET=aarch64-apple-darwin; SWIFT_TRIPLE=arm64-apple-macosx13.0; ARCH_SUFFIX=-AppleSilicon ;;
 *) echo "SHENG_TARGET_ARCH must be native, arm64 or x86_64." >&2; exit 2 ;;
esac
if [ -n "$RUST_TARGET" ]; then
  if [ "$MODE" != --build-only ]; then echo "Explicit architecture builds require --build-only." >&2;exit 2;fi
  SCRATCH_PATH=".build/$RUST_TARGET"
  export SHENG_ENGINE_LIBRARY_DIR="$SDK_DIR/target/$RUST_TARGET/$SHENG_ENGINE_PROFILE"
fi
build_engine() {
  if [ "$BUILD_CONFIGURATION" = release ]; then
    (cd "$SDK_DIR" && cargo build --locked -p sheng-engine --release "$@")
  else
    (cd "$SDK_DIR" && cargo build --locked -p sheng-engine "$@")
  fi
}
if [ -n "$RUST_TARGET" ]; then build_engine --target "$RUST_TARGET"; else build_engine; fi
build_swift() {
  if [ -n "$SWIFT_TRIPLE" ]; then
    swift build --scratch-path "$SCRATCH_PATH" --disable-sandbox -c "$BUILD_CONFIGURATION" --triple "$SWIFT_TRIPLE" "$@"
  else
    swift build --scratch-path "$SCRATCH_PATH" --disable-sandbox -c "$BUILD_CONFIGURATION" "$@"
  fi
}
build_swift
BIN_DIR="$(build_swift --show-bin-path)"
FINAL_BUNDLE="$ROOT_DIR/dist/$APP_NAME$ARCH_SUFFIX.app"
mkdir -p "$ROOT_DIR/dist"
STAGING_ROOT="$(mktemp -d "$ROOT_DIR/dist/.sheng-build.XXXXXX")"
APP_BUNDLE="$STAGING_ROOT/$APP_NAME.app"
trap 'rm -rf "$STAGING_ROOT"' EXIT
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp -R "$ROOT_DIR/Resources/"*.lproj "$APP_BUNDLE/Contents/Resources/"
cp "$ROOT_DIR/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
cp "$ROOT_DIR/Resources/"SidebarMark*.png "$APP_BUNDLE/Contents/Resources/"
# Accent colour for native controls (focus rings, selection); matches ShengStyle.accent.
xcrun actool "$ROOT_DIR/Resources/Assets.xcassets" --compile "$APP_BUNDLE/Contents/Resources" --platform macosx \
  --minimum-deployment-target 13.0 --output-format human-readable-text --notices --warnings \
  --output-partial-info-plist "$STAGING_ROOT/assets-info.plist" >/dev/null
if [ -f "$SDK_DIR/THIRD_PARTY_NOTICES.md" ]; then cp "$SDK_DIR/THIRD_PARTY_NOTICES.md" "$APP_BUNDLE/Contents/Resources/ThirdPartyNotices.txt"; fi

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>$APP_NAME</string>
<key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
<key>CFBundleName</key><string>声笺</string>
<key>CFBundleDisplayName</key><string>声笺</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>NSAccentColorName</key><string>AccentColor</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>NSMicrophoneUsageDescription</key><string>仅在你选择麦克风并开启字幕时采集声音。</string>
<key>NSSpeechRecognitionUsageDescription</key><string>将你选择的音源转换为实时字幕。</string>
<key>NSAudioCaptureUsageDescription</key><string>仅在你开启系统声音字幕时采集系统音频。</string>
<key>NSLocalNetworkUsageDescription</key><string>连接你选择的局域网字幕服务。</string>
<key>NSAppTransportSecurity</key><dict><key>NSAllowsLocalNetworking</key><true/></dict>
</dict></plist>
PLIST
# Never create certificates or modify keychain access rules.
source "$ROOT_DIR/script/signing_identity.sh"
IDENTITY="$(resolve_signing_identity)"

/usr/bin/codesign --force --sign "$IDENTITY" "$APP_BUNDLE"
/usr/bin/codesign --verify --strict "$APP_BUNDLE"
source "$ROOT_DIR/script/publish_bundle.sh"
publish_bundle "$APP_BUNDLE" "$FINAL_BUNDLE"
APP_BUNDLE="$FINAL_BUNDLE"
case "$MODE" in
 --build-only) echo "$APP_BUNDLE" ;;
 --debug) lldb -- "$APP_BUNDLE/Contents/MacOS/$APP_NAME" ;;
 --logs) /usr/bin/open -n "$APP_BUNDLE"; /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\"" ;;
 --telemetry) /usr/bin/open -n "$APP_BUNDLE"; /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\"" ;;
 --verify) /usr/bin/open -n "$APP_BUNDLE"; sleep 1; /usr/bin/pgrep -x "$APP_NAME" >/dev/null ;;
 run) /usr/bin/open -n "$APP_BUNDLE" ;;
esac
