#!/bin/zsh
# Start Lace.app at login: writes ~/Library/LaunchAgents/local.lace-ember.lace.plist
# for this user and loads it.
set -e
plist=$HOME/Library/LaunchAgents/local.lace-ember.lace.plist
mkdir -p ${plist:h}
cat > $plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>local.lace-ember.lace</string>
  <key>ProgramArguments</key>
  <array><string>/usr/bin/open</string><string>-a</string><string>$HOME/Applications/Lace.app</string></array>
  <key>RunAtLoad</key><true/>
  <key>LimitLoadToSessionType</key><string>Aqua</string>
</dict>
</plist>
PLIST
launchctl bootout gui/$(id -u) $plist 2>/dev/null || true
launchctl bootstrap gui/$(id -u) $plist
echo "Lace will start at login ($plist)"
