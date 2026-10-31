#!/bin/sh
# Builds build/Finit.app. `./build.sh install` also copies it to ~/Applications.
# The icon is pre-rendered; regenerate it with `swift Scripts/make-icon.swift`.
set -eu
cd "$(dirname "$0")"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/Finit"
APP=build/Finit.app

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Finit"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
strip -x "$APP/Contents/MacOS/Finit"
codesign --force --sign - "$APP"
echo "Built $APP ($(du -k "$APP/Contents/MacOS/Finit" | cut -f1) KB binary)"

if [ "${1:-}" = install ]; then
  mkdir -p "$HOME/Applications"
  rm -rf "$HOME/Applications/Finit.app"
  cp -R "$APP" "$HOME/Applications/"
  echo "Installed to ~/Applications/Finit.app"
fi
