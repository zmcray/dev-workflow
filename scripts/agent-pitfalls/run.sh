#!/usr/bin/env bash
# Reruns the agent pitfall study's deterministic numbers for the last N days (default 30)
# and compares them with the 2026-10-16 baseline. Private outputs stay in .local/.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
DAYS="${1:-30}"
UNTIL="$(date +%F)"
SINCE="$(date -v-"${DAYS}"d +%F 2>/dev/null || date -d "-${DAYS} days" +%F)"
OUT="$ROOT/.local/agent-pitfalls-${DAYS}d-$UNTIL"
mkdir -p "$OUT"
for r in pulse motus saidso pulse-ios telos argus sonar quoting dev-workflow mcray-os-skills; do
  [ -d "$HOME/Developer/$r" ] && git -C "$HOME/Developer/$r" fetch -q origin || true
done
python3 -I "$HERE/extract_messages.py" --out "$OUT/messages" --days "$DAYS" > "$OUT/extract.log"
node "$HERE/metrics.mjs" --since "$SINCE" --until "$UNTIL" --messages "$OUT/messages" \
  --baseline "$HERE/baseline-2026-10-16.json" --json "$OUT/metrics.json" | tee "$OUT/report.md"
echo
echo "Saved to $OUT. For the judged numbers, run the classifier pass in $HERE/classify-prompt.md over $OUT/messages."
