#!/bin/bash
set -e

echo "🔨 Building MacBookNotch in Release mode..."
swift build -c release

echo "📦 Creating App Bundle Structure..."
APP_DIR="./build/MacBookNotch.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

cp .build/release/MacBookNotch "$MACOS_DIR/MacBookNotch"
chmod +x "$MACOS_DIR/MacBookNotch"

cat << 'EOF' > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MacBookNotch</string>
    <key>CFBundleIdentifier</key>
    <string>com.macbooknotch.app</string>
    <key>CFBundleName</key>
    <string>MacBookNotch</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
EOF

echo "🗜️ Creating Zip Archive..."
cd ./build
rm -f MacBookNotch.zip MacBookNotch.dmg
zip -r -q -y MacBookNotch.zip MacBookNotch.app

echo "💿 Creating Drag-to-Install DMG..."
DMG_TEMP_DIR="./dmg_temp"
rm -rf "$DMG_TEMP_DIR"
mkdir -p "$DMG_TEMP_DIR"
cp -r MacBookNotch.app "$DMG_TEMP_DIR/"
ln -s /Applications "$DMG_TEMP_DIR/Applications"

hdiutil create -volname "MacBookNotch" -srcfolder "$DMG_TEMP_DIR" -ov -format UDZO MacBookNotch.dmg
rm -rf "$DMG_TEMP_DIR"

echo "✅ Distribution packages created successfully:"
echo "   - ./build/MacBookNotch.dmg"
echo "   - ./build/MacBookNotch.zip"
