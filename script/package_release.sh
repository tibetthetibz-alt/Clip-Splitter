#!/usr/bin/env bash
# Builds a universal macOS .app with bundled FFmpeg and a zip for GitHub Releases.
set -euo pipefail

EXECUTABLE_NAME="ClipSplitter"
DISPLAY_NAME="Clip Splitter"
BUNDLE_ID="com.codex.ClipSplitter"
MIN_MACOS="14.0"
FFMPEG_STATIC_VERSION="b6.1.2-rc.1"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$DISPLAY_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BIN="$APP_RESOURCES/bin"
APP_BINARY="$APP_MACOS/$EXECUTABLE_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
ZIP_NAME="Clip-Splitter-macOS-Universal.zip"
ZIP_PATH="$DIST_DIR/$ZIP_NAME"

VERSION="${RELEASE_VERSION:-}"
if [[ -z "$VERSION" ]]; then
  VERSION="$(git -C "$ROOT_DIR" describe --tags --abbrev=0 2>/dev/null || true)"
fi
VERSION="${VERSION#v}"
VERSION="${VERSION:-1.0.0}"

echo "==> Clip Splitter release build (version $VERSION)"

build_arch() {
  local arch="$1"
  local triple="${arch}-apple-macosx"
  echo "    Building $arch..." >&2
  swift build -c release --triple "$triple" --product "$EXECUTABLE_NAME" >&2
  local bin="$ROOT_DIR/.build/${triple}/release/$EXECUTABLE_NAME"
  if [[ ! -f "$bin" ]]; then
    echo "error: expected binary at $bin" >&2
    exit 1
  fi
  printf '%s' "$bin"
}

echo "==> Compiling universal app binary"
ARM_BIN="$(build_arch arm64)"
X64_BIN="$(build_arch x86_64)"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

download_ffmpeg_tool() {
  local tool="$1"
  local arch_label="$2"
  local url="https://github.com/descriptinc/ffmpeg-ffprobe-static/releases/download/${FFMPEG_STATIC_VERSION}/${tool}-darwin-${arch_label}"
  local dest="$TMP/${tool}-${arch_label}"
  echo "    Downloading ${tool} (${arch_label})..." >&2
  curl -fsSL "$url" -o "$dest"
  chmod +x "$dest"
  printf '%s' "$dest"
}

lipo_universal() {
  local arm="$1"
  local x64="$2"
  local out="$3"
  lipo -create "$arm" "$x64" -output "$out"
  chmod +x "$out"
}

echo "==> Downloading universal FFmpeg tools"
ARM_FFMPEG="$(download_ffmpeg_tool ffmpeg arm64)"
X64_FFMPEG="$(download_ffmpeg_tool ffmpeg x64)"
ARM_FFPROBE="$(download_ffmpeg_tool ffprobe arm64)"
X64_FFPROBE="$(download_ffmpeg_tool ffprobe x64)"

echo "==> Assembling $DISPLAY_NAME.app"
rm -rf "$DIST_DIR/SlipSplitter.app" "$DIST_DIR/ClipSplitter.app" "$APP_BUNDLE" "$ZIP_PATH"
mkdir -p "$APP_MACOS" "$APP_BIN"

lipo -create "$ARM_BIN" "$X64_BIN" -output "$APP_BINARY"
chmod +x "$APP_BINARY"

lipo_universal "$ARM_FFMPEG" "$X64_FFMPEG" "$APP_BIN/ffmpeg"
lipo_universal "$ARM_FFPROBE" "$X64_FFPROBE" "$APP_BIN/ffprobe"

RESOURCE_BUNDLE="$(dirname "$ARM_BIN")/ClipSplitter_ClipSplitter.bundle"
if [[ -d "$RESOURCE_BUNDLE" ]]; then
  cp -R "$RESOURCE_BUNDLE" "$APP_RESOURCES/"
  if [[ -f "$RESOURCE_BUNDLE/AppIcon.icns" ]]; then
    cp "$RESOURCE_BUNDLE/AppIcon.icns" "$APP_RESOURCES/AppIcon.icns"
  fi
fi

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>$EXECUTABLE_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$DISPLAY_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$DISPLAY_NAME</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$VERSION</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_MACOS</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

echo "==> Signing app (ad-hoc)"
xattr -cr "$APP_BUNDLE"
codesign --force --deep --sign - "$APP_BUNDLE"

echo "==> Creating $ZIP_NAME"
ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ZIP_PATH"

echo ""
echo "Done."
echo "  App:  $APP_BUNDLE"
echo "  Zip:  $ZIP_PATH"
file "$APP_BINARY" "$APP_BIN/ffmpeg" "$APP_BIN/ffprobe"
