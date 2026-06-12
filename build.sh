#!/bin/bash
# Builds dist/AutoBrowser.app from the SwiftPM package — no Xcode project needed.
# Usage:  ./build.sh           build only
#         ./build.sh install   build, copy to /Applications, register, relaunch
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP="dist/AutoBrowser.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp .build/release/AutoBrowser "$APP/Contents/MacOS/AutoBrowser"
cp SupportFiles/Info.plist "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

codesign --force --sign - "$APP"

echo
echo "Built $APP"

if [ "${1:-}" = "install" ]; then
    LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
    pkill -x AutoBrowser 2>/dev/null || true
    rm -rf /Applications/AutoBrowser.app
    cp -R "$APP" /Applications/
    "$LSREGISTER" -f /Applications/AutoBrowser.app
    open /Applications/AutoBrowser.app
    echo "Installed and launched /Applications/AutoBrowser.app"
else
    echo "Install:  ./build.sh install"
fi
