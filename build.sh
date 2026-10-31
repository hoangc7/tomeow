#!/bin/sh
# Builds build/Tomeow.app. `./build.sh install` also copies it to ~/Applications.
# The icon is pre-rendered; regenerate it with `swift Scripts/make-icon.swift`.
set -eu
cd "$(dirname "$0")"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/Tomeow"
APP=build/Tomeow.app

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Tomeow"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
strip -x "$APP/Contents/MacOS/Tomeow"
codesign --force --sign - "$APP"
echo "Built $APP ($(du -k "$APP/Contents/MacOS/Tomeow" | cut -f1) KB binary)"

if [ "${1:-}" = install ]; then
  mkdir -p "$HOME/Applications"
  rm -rf "$HOME/Applications/Tomeow.app"
  cp -R "$APP" "$HOME/Applications/"
  echo "Installed to ~/Applications/Tomeow.app"
fi
