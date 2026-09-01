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

cp Resources/Info.plist "$CONTENTS_DIR/Info.plist"

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
