#!/bin/bash
set -e

echo "🔨 Building MacBookNotch in Release mode..."
swift build -c release

APP_NAME="MacBookNotch.app"
APP_DIR="./build/$APP_NAME"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "📦 Creating App Bundle Structure at $APP_DIR..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

cp .build/release/MacBookNotch "$MACOS_DIR/MacBookNotch"
cp Resources/Info.plist "$CONTENTS_DIR/Info.plist"

chmod +x "$MACOS_DIR/MacBookNotch"

echo "✅ App bundle created successfully: $APP_DIR"
echo "🚀 To run: open $APP_DIR or .build/release/MacBookNotch"
