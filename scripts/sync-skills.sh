#!/usr/bin/env bash
#
# sync-skills.sh
# Daily keep-current job for a factory Mac. Run by the com.mcray.skill-sync launch agent
# (see install-skill-sync.sh); safe to run by hand.
#
#   1. Fast-forwards ~/Developer/dev-workflow and ~/Developer/software-factory from GitHub.
#      A repo with local changes or a diverged branch is skipped, never touched.
#   2. Re-runs deploy-skills.sh only when a deployed skill no longer matches its source.
#      No change upstream = nothing reinstalled.
#
# software-factory's docs (DISPATCH.md, SORT.md) are read from the repo at run time, so the
# pull is enough for them; its folder skills (wizard) are checked and reinstalled like the rest.
#
# Log: ~/Library/Logs/skill-sync.log

set -uo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

DEV="$HOME/Developer"
WF="$DEV/dev-workflow"
PORTABLE=( factory packets caspian )

log() { echo "$(date '+%Y-%m-%d %H:%M') $*"; }

for r in dev-workflow software-factory; do
  p="$DEV/$r"
  if [[ ! -d "$p/.git" ]]; then log "$r: not cloned, skipped (run setup-factory-machine.sh)"; continue; fi
  if [[ -n "$(git -C "$p" status --porcelain)" ]]; then log "$r: local changes, not pulled"; continue; fi
  before="$(git -C "$p" rev-parse HEAD)"
  if ! git -C "$p" pull -q --ff-only 2>/dev/null; then log "$r: pull failed (offline or diverged)"; continue; fi
  after="$(git -C "$p" rev-parse HEAD)"
  [[ "$before" == "$after" ]] && log "$r: up to date" || log "$r: pulled ${before:0:7}..${after:0:7}"
done

# Deployed copy vs source. Claude gets the file as-is; Codex and Cursor get it minus
# argument-hint (same render as deploy-skills.sh).
stale=()
for n in "${PORTABLE[@]}"; do
  src="$WF/commands/$n.md"
  [[ -f "$src" ]] || continue
  cmp -s "$src" "$HOME/.claude/commands/$n.md" || { stale+=("$n"); continue; }
  for d in "$HOME/.agents/skills" "$HOME/.cursor/skills"; do
    grep -v '^argument-hint:' "$src" | cmp -s - "$d/$n/SKILL.md" || { stale+=("$n"); break; }
  done
done

# Folder skills (software-factory/skills): any file that differs or is missing counts.
for n in wizard; do
  src="$DEV/software-factory/skills/$n"
  [[ -d "$src" ]] || continue
  for d in "$HOME/.claude/skills" "$HOME/.agents/skills" "$HOME/.cursor/skills"; do
    diff -rq "$src" "$d/$n" 2>/dev/null | grep -q "^Only in $src\|^Files " && { stale+=("$n"); break; }
    [[ -d "$d/$n" ]] || { stale+=("$n"); break; }
  done
done

if [[ ${#stale[@]} -eq 0 ]]; then
  log "skills: current, nothing reinstalled"
else
  log "skills: changed (${stale[*]}), reinstalling"
  bash "$WF/deploy-skills.sh" >/dev/null && log "skills: reinstalled" || log "skills: deploy FAILED"
fi
