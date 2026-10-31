#!/bin/sh
# Builds build.noindex/Tomeow.app. `./build.sh install` also copies it to /Applications.
# The .noindex suffix keeps Spotlight from listing the build next to the installed app.
# The icon is pre-rendered; regenerate it with `swift Scripts/make-icon.swift`.
set -eu
cd "$(dirname "$0")"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/Tomeow"
APP=build.noindex/Tomeow.app

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Tomeow"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
strip -x "$APP/Contents/MacOS/Tomeow"
codesign --force --sign - "$APP"
echo "Built $APP ($(du -k "$APP/Contents/MacOS/Tomeow" | cut -f1) KB binary)"

if [ "${1:-}" = install ]; then
  rm -rf /Applications/Tomeow.app
  cp -R "$APP" /Applications/
  echo "Installed to /Applications/Tomeow.app"
fi
