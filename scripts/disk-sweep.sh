#!/bin/bash
# disk-sweep.sh — autonomous no-regret disk cleanup for macOS.
# Clears only recurring, self-rebuilding bloat. Makes NO judgment calls.
# Never touches: Claude VM image, active repos, real data, Docker VM image.
# Logs to ~/Library/Logs/disk-sweep.log. Safe to run unattended (launchd).
#
# Simulators are not swept here: sim-reaper.sh owns them and runs four times a day.
#
# Manual run:   bash ~/Developer/dev-workflow/scripts/disk-sweep.sh
# Installed by: install-disk-sweep.sh (com.mcray.disk-sweep, Mondays 10:00)

LOG="$HOME/Library/Logs/disk-sweep.log"
exec >> "$LOG" 2>&1

free_gb () { df -g / | awk 'NR==2{print $4}'; }

echo "===================================================="
echo " disk-sweep  $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "===================================================="
BEFORE=$(free_gb)
echo "Free before: ${BEFORE} GB"

# 1. App caches — clear all EXCEPT Apple-protected and re-download-heavy sets.
#    ms-playwright (browser binaries) and Homebrew (bottles) are excluded to
#    avoid re-download churn; Homebrew is cleaned via its own tool below.
echo "-- clearing app caches"
find "$HOME/Library/Caches" -maxdepth 1 -mindepth 1 \
  ! -name 'com.apple.*' ! -name 'ms-playwright' ! -name 'Homebrew' \
  -exec rm -rf {} + 2>/dev/null

# 2. Package-manager caches — tool-native, always safe.
echo "-- npm cache clean"
command -v npm  >/dev/null 2>&1 && npm cache clean --force >/dev/null 2>&1
echo "-- pnpm store prune"
command -v pnpm >/dev/null 2>&1 && pnpm store prune >/dev/null 2>&1
echo "-- brew cleanup"
command -v brew >/dev/null 2>&1 && brew cleanup -q >/dev/null 2>&1
echo "-- pip cache purge"
command -v pip3 >/dev/null 2>&1 && pip3 cache purge >/dev/null 2>&1

# 3. Xcode junk — regenerates on next build / device connect.
echo "-- Xcode DerivedData + CoreSimulator caches"
rm -rf "$HOME/Library/Developer/Xcode/DerivedData/"* 2>/dev/null
rm -rf "$HOME/Library/Developer/CoreSimulator/Caches/"* 2>/dev/null

# 4. Codex runtime cache — re-downloads on demand.
echo "-- codex runtime cache"
rm -rf "$HOME/.cache/codex-runtimes/"* 2>/dev/null

# 5. XcodeBuildMCP workspaces — build-for-testing output that never self-reaps.
#    Observed 2026-08-18: a single motus workspace reached 15 GB in ~4 days
#    (13 GB of it in test-products). All four subdirs are regenerable build
#    output, never source. Keeps anything touched in the last 7 days so the
#    current build is not thrown away.
XBM="$HOME/Library/Developer/XcodeBuildMCP/workspaces"
if [ -d "$XBM" ]; then
  echo "-- XcodeBuildMCP build output (>7d old)"
  find "$XBM" -mindepth 2 -maxdepth 2 -type d \
       \( -name test-products -o -name result-bundles -o -name DerivedData -o -name logs \) \
       -print0 2>/dev/null |
  while IFS= read -r -d '' d; do
    find "$d" -mindepth 1 -maxdepth 1 -mtime +7 -exec rm -rf {} + 2>/dev/null
  done
  # Drop whole workspace dirs untouched for 30+ days (stale project checkouts).
  find "$XBM" -mindepth 1 -maxdepth 1 -type d -mtime +30 -exec rm -rf {} + 2>/dev/null
fi

# 8. Docker — PRUNE ONLY (dangling). Never wipes the VM image unattended.
#    Reports if the VM image is large so a full reset can be done attended.
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  echo "-- docker prune (dangling only)"
  docker system prune -f >/dev/null 2>&1
fi
DOCKER_RAW="$HOME/Library/Containers/com.docker.docker/Data/vms"
if [ -d "$DOCKER_RAW" ]; then
  SZ=$(du -sg "$DOCKER_RAW" 2>/dev/null | awk '{print $1}')
  if [ "${SZ:-0}" -ge 8 ]; then
    echo "NOTE: Docker VM image is ${SZ} GB. Run an attended full reset to reclaim it (say 'clean up my disk')."
  fi
fi

AFTER=$(free_gb)
echo "Free after:  ${AFTER} GB   (reclaimed ~$((AFTER - BEFORE)) GB)"
echo "-- done"
echo
