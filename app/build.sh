#!/bin/zsh
# Build Lace.app into ~/Applications and (re)start it.
set -e
src=${0:A:h}
app=$HOME/Applications/Lace.app
build=$(mktemp -d)/Lace.app
mkdir -p $build/Contents/{MacOS,Resources}
xcrun swiftc -O -o $build/Contents/MacOS/Lace $src/main.swift \
  -framework Cocoa -framework WebKit -framework IOKit -framework Network
cp -R $src/web $build/Contents/Resources/web
cat > $build/Contents/Info.plist <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Lace</string>
  <key>CFBundleIdentifier</key><string>local.lace-ember.lace</string>
  <key>CFBundleExecutable</key><string>Lace</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
EOF
# Sign with the local "Lace Local Code Signing" certificate (login keychain) so
# the app's identity, and so its Accessibility grant, survives rebuilds.
# Falls back to ad-hoc on a Mac without it (README: "Stable signature").
if security find-identity -p codesigning | grep -q "Lace Local Code Signing"; then
  codesign --force -s "Lace Local Code Signing" $build
else
  echo "warning: no 'Lace Local Code Signing' cert; ad-hoc signing (Accessibility resets on every rebuild)"
  codesign --force -s - $build
fi
pkill -x Lace 2>/dev/null || true
for i in {1..20}; do pgrep -x Lace >/dev/null || break; sleep 0.2; done
mkdir -p $HOME/Applications
rm -rf $app && mv $build $app
open $app
echo "built and launched $app"
