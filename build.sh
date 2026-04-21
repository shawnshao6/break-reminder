#!/bin/bash
# Build script for BreakReminder
# Usage: ./build.sh
set -e

cd "$(dirname "$0")"

echo "==> Compiling BreakReminder.swift..."
swiftc -O -o BreakReminder BreakReminder.swift -framework Cocoa

echo "==> Assembling BreakReminder.app bundle..."
mkdir -p BreakReminder.app/Contents/MacOS
mkdir -p BreakReminder.app/Contents/Resources
cp BreakReminder BreakReminder.app/Contents/MacOS/BreakReminder

if [ ! -f BreakReminder.app/Contents/Info.plist ]; then
cat > BreakReminder.app/Contents/Info.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>BreakReminder</string>
    <key>CFBundleIdentifier</key>
    <string>com.local.breakreminder</string>
    <key>CFBundleName</key>
    <string>BreakReminder</string>
    <key>CFBundleDisplayName</key>
    <string>Break Reminder</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>11.0</string>
</dict>
</plist>
PLIST
fi

INSTALLED_APP="/Applications/BreakReminder.app"
if [ -d "$INSTALLED_APP" ]; then
    echo "==> Detected installed copy at $INSTALLED_APP — syncing..."
    cp BreakReminder "$INSTALLED_APP/Contents/MacOS/BreakReminder"
    cp BreakReminder.app/Contents/Info.plist "$INSTALLED_APP/Contents/Info.plist"

    if pgrep -f "BreakReminder" >/dev/null; then
        echo "==> Restarting running instance..."
        pkill -f "BreakReminder" || true
        sleep 1
        open "$INSTALLED_APP"
    fi
fi

echo ""
echo "Build complete."
echo ""
if [ -d "$INSTALLED_APP" ]; then
    echo "Both copies are in sync:"
    echo "  - $(pwd)/BreakReminder.app  (dev copy)"
    echo "  - $INSTALLED_APP            (installed copy, used by Login Items)"
else
    echo "To run:"
    echo "  open BreakReminder.app"
    echo ""
    echo "To install system-wide (recommended, makes it show up in Login Items):"
    echo "  mv BreakReminder.app /Applications/"
    echo "  (after that, future builds auto-sync /Applications/BreakReminder.app)"
fi
