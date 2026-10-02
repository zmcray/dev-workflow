#!/usr/bin/env bash
#
# install-disk-sweep.sh
# Installs (or refreshes) the com.mcray.disk-sweep launch agent: disk-sweep.sh every Monday at
# 10:00 local. If the Mac is asleep then, launchd runs it at the next wake. Safe to re-run.
# Simulators are handled separately, four times a day, by install-sim-reaper.sh.
#
# Remove:  launchctl bootout gui/$(id -u)/com.mcray.disk-sweep
#          rm ~/Library/LaunchAgents/com.mcray.disk-sweep.plist

set -euo pipefail

LABEL="com.mcray.disk-sweep"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
SCRIPT="$HOME/Developer/dev-workflow/scripts/disk-sweep.sh"

[[ -f "$SCRIPT" ]] || { echo "FATAL: $SCRIPT not found"; exit 1; }
mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"

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

    <!-- Mondays at 10:00 local. StartCalendarInterval is wall-clock and catches up at next
         wake; StartInterval would restart its count at every login. -->
    <key>StartCalendarInterval</key>
    <dict>
        <key>Weekday</key>
        <integer>1</integer>
        <key>Hour</key>
        <integer>10</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>RunAtLoad</key>
    <false/>

    <!-- The script appends its own report to ~/Library/Logs/disk-sweep.log. -->
    <key>StandardOutPath</key>
    <string>$HOME/Library/Logs/disk-sweep.out</string>
    <key>StandardErrorPath</key>
    <string>$HOME/Library/Logs/disk-sweep.err</string>

    <key>ProcessType</key>
    <string>Background</string>
</dict>
</plist>
EOF

plutil -lint -s "$PLIST"
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "installed $LABEL: Mondays 10:00, log ~/Library/Logs/disk-sweep.log"
