#!/usr/bin/env bash
#
# install-sim-reaper.sh
# Installs (or refreshes) the com.mcray.sim-reaper launch agent: sim-reaper.sh at 00:00, 06:00,
# 12:00 and 18:00 local, and once at login. A simulator left idle is gone within about 12 hours,
# so a run of heavy factory nights cannot pile them up (MCR-2346). If the Mac is asleep at a
# slot, launchd runs it at the next wake. Safe to re-run.
#
# Remove:  launchctl bootout gui/$(id -u)/com.mcray.sim-reaper
#          rm ~/Library/LaunchAgents/com.mcray.sim-reaper.plist

set -euo pipefail

LABEL="com.mcray.sim-reaper"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
SCRIPT="$HOME/Developer/dev-workflow/scripts/sim-reaper.sh"

[[ -f "$SCRIPT" ]] || { echo "FATAL: $SCRIPT not found"; exit 1; }
mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"

slots=""
for h in 0 6 12 18; do
  slots+="        <dict><key>Hour</key><integer>$h</integer><key>Minute</key><integer>0</integer></dict>
"
done

cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>

    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$SCRIPT</string>
    </array>

    <!-- Every six hours on the wall clock. StartCalendarInterval catches up at next wake;
         StartInterval would restart its count at every login. -->
    <key>StartCalendarInterval</key>
    <array>
$slots    </array>
    <key>RunAtLoad</key>
    <true/>

    <key>StandardOutPath</key>
    <string>$HOME/Library/Logs/sim-reaper.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/Library/Logs/sim-reaper.log</string>

    <key>ProcessType</key>
    <string>Background</string>
</dict>
</plist>
EOF

plutil -lint -s "$PLIST"
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "installed $LABEL: 00:00, 06:00, 12:00, 18:00 and at login, log ~/Library/Logs/sim-reaper.log"
