#!/usr/bin/env bash
#
# install-skill-sync.sh
# Installs (or refreshes) the com.mcray.skill-sync launch agent: sync-skills.sh once a day
# at 17:00 local, before the night shift. If the Mac is asleep at 17:00, launchd runs it
# at the next wake. Safe to re-run.
#
# Remove:  launchctl bootout gui/$(id -u)/com.mcray.skill-sync
#          rm ~/Library/LaunchAgents/com.mcray.skill-sync.plist

set -euo pipefail

LABEL="com.mcray.skill-sync"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
SCRIPT="$HOME/Developer/dev-workflow/scripts/sync-skills.sh"

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

    <!-- Daily at 17:00 local, before the night shift. StartCalendarInterval is wall-clock
         and catches up at next wake; StartInterval would restart its count at every login. -->
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>17</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>RunAtLoad</key>
    <false/>

    <key>StandardOutPath</key>
    <string>$HOME/Library/Logs/skill-sync.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/Library/Logs/skill-sync.log</string>

    <key>ProcessType</key>
    <string>Background</string>
</dict>
</plist>
EOF

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "installed $LABEL: daily 17:00, log ~/Library/Logs/skill-sync.log"
