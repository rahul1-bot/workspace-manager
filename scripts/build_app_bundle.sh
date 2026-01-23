#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

CONFIG="${CONFIG:-debug}"
swift build -c "$CONFIG"

APP_DIR="$ROOT_DIR/Build/WorkspaceManager.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$ROOT_DIR/.build/$CONFIG/WorkspaceManager" "$MACOS_DIR/WorkspaceManager"
chmod +x "$MACOS_DIR/WorkspaceManager"

# Copy SwiftPM resource bundle (Bundle.module) if present
RESOURCE_BUNDLE="$ROOT_DIR/.build/$CONFIG/WorkspaceManager_WorkspaceManager.bundle"
if [ -d "$RESOURCE_BUNDLE" ]; then
  rm -rf "$RESOURCES_DIR/$(basename "$RESOURCE_BUNDLE")"
  cp -R "$RESOURCE_BUNDLE" "$RESOURCES_DIR/"
fi

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>WorkspaceManager</string>
    <key>CFBundleDisplayName</key>
    <string>WorkspaceManager</string>
    <key>CFBundleIdentifier</key>
    <string>com.rahul.workspace-manager</string>
    <key>CFBundleExecutable</key>
    <string>WorkspaceManager</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST
