#!/usr/bin/env bash
#
# sim-reaper.sh
# Deletes iOS simulators nobody is using, so factory nights and CI cannot fill the disk between
# sweeps. MCR-2346: a few heavy factory nights left 146 GB of devices on the iMac and main CI
# failed with "No space left on device". Runs four times a day (install-sim-reaper.sh).
#
# Rules:
#   - Never touches a simulator that is not shut down (booted, booting, shutting down).
#   - Deletes a shut-down simulator idle for IDLE_HOURS (default 6). Idle = time since its
#     device.plist last changed; CoreSimulator rewrites it on every boot and shutdown.
#     Everything that reuses a named simulator (Saidso CI, capture scripts, agent loops)
#     creates it again when it is missing.
#   - Under LOW_DISK_GB free on the data volume (default 40), the idle limit drops to
#     LOW_DISK_IDLE_MIN minutes (default 30).
#   - Covers the default device set and XCTestDevices (Xcode's parallel-testing clones).
#   - Deletes through simctl so CoreSimulator stays in sync. A device folder with no
#     device.plist is invisible to simctl, so once idle it is removed directly.
#   - Fails closed: if simctl cannot list a set, nothing in that set is deleted.
#
# Usage:
#   bash sim-reaper.sh --dry-run   # report only, delete nothing
#   bash sim-reaper.sh
#
# Log (when run by launchd): ~/Library/Logs/sim-reaper.log

set -uo pipefail

IDLE_HOURS="${IDLE_HOURS:-6}"
LOW_DISK_GB="${LOW_DISK_GB:-40}"
LOW_DISK_IDLE_MIN="${LOW_DISK_IDLE_MIN:-30}"
SETS=( "$HOME/Library/Developer/CoreSimulator/Devices" "$HOME/Library/Developer/XCTestDevices" )
UDID_RE='^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$'

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

# The sealed / volume reports misleading free space; the data volume is the one that fills.
free_gb() { df -g /System/Volumes/Data | awk 'NR==2 {print $4}'; }

FREE_BEFORE="$(free_gb)"
if (( FREE_BEFORE < LOW_DISK_GB )); then
  LIMIT=$(( LOW_DISK_IDLE_MIN * 60 )); MODE="low disk: idle > ${LOW_DISK_IDLE_MIN}m"
else
  LIMIT=$(( IDLE_HOURS * 3600 )); MODE="idle > ${IDLE_HOURS}h"
fi
NOW="$(date +%s)"

echo "== sim-reaper $(date '+%Y-%m-%d %H:%M %Z')  free ${FREE_BEFORE} GB  ($MODE)$([[ $DRY_RUN -eq 1 ]] && echo '  DRY RUN')"

reaped=0; kept=0; reaped_kb=0
for set in "${SETS[@]}"; do
  [[ -d "$set" ]] || continue

  # Anything not shut down is in use by a person, a test run, or a CI job. A missing or
  # malformed .devices makes to_entries fail, so a bad listing never reads as "nothing busy".
  if ! json="$(xcrun simctl --set "$set" list devices -j 2>/dev/null)" \
     || ! busy="$(jq -r '.devices | to_entries[] | .value[] | select(.state != "Shutdown") | .udid' <<<"$json" 2>/dev/null)"; then
    echo "  skip $set: simctl could not list it"
    continue
  fi

  for dir in "$set"/*/; do
    dir="${dir%/}"; udid="${dir##*/}"
    [[ "$udid" =~ $UDID_RE ]] || continue
    if grep -qx "$udid" <<<"$busy"; then kept=$((kept + 1)); continue; fi

    plist="$dir/device.plist"
    if [[ -f "$plist" ]]; then stamp="$(stat -f %m "$plist")"; else stamp="$(stat -f %m "$dir")"; fi
    idle=$(( NOW - stamp ))
    if (( idle < LIMIT )); then kept=$((kept + 1)); continue; fi

    name="$(plutil -extract name raw "$plist" 2>/dev/null || echo '(no device.plist)')"
    kb="$(du -sk "$dir" 2>/dev/null | awk '{print $1}')"
    echo "  delete  $name  $udid  idle $(( idle / 3600 ))h  $(( ${kb:-0} / 1024 )) MB"
    if [[ $DRY_RUN -eq 0 ]]; then
      if [[ -f "$plist" ]]; then
        # simctl refuses a device that booted since the listing above, which is what we want.
        xcrun simctl --set "$set" delete "$udid" || { echo "  FAILED  $udid (left in place)"; continue; }
      else
        rm -rf "$dir"
      fi
    fi
    reaped=$((reaped + 1)); reaped_kb=$(( reaped_kb + ${kb:-0} ))
  done

  # Devices whose runtime is gone; simctl cannot boot them, so they are never in use.
  [[ $DRY_RUN -eq 1 ]] || xcrun simctl --set "$set" delete unavailable >/dev/null 2>&1
done

echo "   reaped $reaped ($(( reaped_kb / 1024 / 1024 )) GB), kept $kept; free now $(free_gb) GB"
