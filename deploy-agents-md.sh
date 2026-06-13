#!/usr/bin/env bash
#
# deploy-agents-md.sh
# Deploys the canonical AGENTS.md workflow block into each repo under ~/Developer,
# and repoints CLAUDE.md to import AGENTS.md so Claude Code reads the same source.
#
# Source of truth: AGENTS.workflow.md (sibling of this script). Edit that file,
# re-run this script, and every repo's canonical block re-syncs. Repo-specific
# context above the block is preserved across re-runs.
#
# Non-destructive: copies/edits only. Backs up any CLAUDE.md it replaces to
# CLAUDE.md.pre-agents.bak. Never deletes. Skips repos not present in ~/Developer.
#
# Usage:
#   bash deploy-agents-md.sh --dry-run    # show what would happen, touch nothing
#   bash deploy-agents-md.sh              # apply

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOW_FILE="$SCRIPT_DIR/AGENTS.workflow.md"
DEV_DIR="$HOME/Developer"
LOG="$SCRIPT_DIR/deploy-$(date +%Y%m%d-%H%M%S).log"

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

# Repos to manage. The script acts only on those that exist in ~/Developer,
# so pending-migration repos are safe to list now; they get picked up once moved.
REPOS=(
  first-tack helm cgsc atlas-os
  forge pulse mcraygroup-site racconto-website learn-anything
  meridian abc-healthcare-scheduling compound palenque larder
)

BEGIN_MARK="<!-- BEGIN CANONICAL WORKFLOW"
END_MARK="<!-- END CANONICAL WORKFLOW -->"

log()  { echo "$*" | tee -a "$LOG"; }
act()  { if [[ $DRY_RUN -eq 1 ]]; then log "  [dry-run] $*"; else eval "$2"; log "  $1"; fi; }

[[ -f "$WORKFLOW_FILE" ]] || { echo "FATAL: canonical block not found at $WORKFLOW_FILE"; exit 1; }

log "=== deploy-agents-md.sh $([[ $DRY_RUN -eq 1 ]] && echo '(DRY RUN)') ==="
log "Canonical block: $WORKFLOW_FILE"
log "Developer dir:   $DEV_DIR"
log ""

# Replace the marked block in $1 with the canonical block (awk: drop old block, insert new).
replace_block() {
  local target="$1"
  awk -v blockfile="$WORKFLOW_FILE" '
    BEGIN { while ((getline line < blockfile) > 0) blk = blk line "\n" }
    index($0, "<!-- BEGIN CANONICAL WORKFLOW") { inblock=1; printf "%s", blk; next }
    index($0, "<!-- END CANONICAL WORKFLOW -->") { inblock=0; next }
    !inblock { print }
  ' "$target" > "$target.tmp" && mv "$target.tmp" "$target"
}

for repo in "${REPOS[@]}"; do
  dir="$DEV_DIR/$repo"
  if [[ ! -d "$dir" ]]; then
    log "SKIP $repo (not in ~/Developer yet)"
    continue
  fi

  log "REPO $repo"
  agents="$dir/AGENTS.md"
  claude="$dir/CLAUDE.md"

  # --- AGENTS.md ---
  if [[ -f "$agents" ]] && grep -q "$BEGIN_MARK" "$agents"; then
    act "AGENTS.md canonical block re-synced" "replace_block \"$agents\""
  elif [[ -f "$agents" ]]; then
    act "AGENTS.md exists, appended canonical block (no marker found)" "cat \"$WORKFLOW_FILE\" >> \"$agents\""
  else
    # New AGENTS.md. Seed the context header from CLAUDE.md body if it has real content,
    # else a stub. Strip any standalone 'Issue tracker:' line (now lives in the block).
    if [[ -f "$claude" ]] && ! grep -q "@AGENTS.md" "$claude" && [[ $(grep -vcE '^\s*$' "$claude") -gt 1 ]]; then
      header="$(grep -vE '^\*\*Issue tracker:\*\*' "$claude")"
      src="migrated from CLAUDE.md"
    else
      header="# ${repo}"$'\n\n'"Project context. Describe build/test commands, architecture, and key conventions here."
      src="new stub header"
    fi
    if [[ $DRY_RUN -eq 1 ]]; then
      log "  [dry-run] AGENTS.md created (${src}) + canonical block"
    else
      { printf '%s\n\n' "$header"; cat "$WORKFLOW_FILE"; } > "$agents"
      log "  AGENTS.md created (${src}) + canonical block"
    fi
  fi

  # --- CLAUDE.md -> import AGENTS.md ---
  if [[ -f "$claude" ]] && grep -q "@AGENTS.md" "$claude"; then
    log "  CLAUDE.md already imports AGENTS.md (left as-is)"
  else
    if [[ -f "$claude" && ! -f "$claude.pre-agents.bak" ]]; then
      act "CLAUDE.md backed up to CLAUDE.md.pre-agents.bak" "cp \"$claude\" \"$claude.pre-agents.bak\""
    fi
    import_body="# Claude Code memory

This repo's instructions live in AGENTS.md, the cross-tool source of truth read by
Claude Code, Codex, Cursor, and other harnesses. Edit AGENTS.md, not this file.

@AGENTS.md"
    if [[ $DRY_RUN -eq 1 ]]; then
      log "  [dry-run] CLAUDE.md rewritten to @AGENTS.md import"
    else
      printf '%s\n' "$import_body" > "$claude"
      log "  CLAUDE.md rewritten to @AGENTS.md import"
    fi
  fi
  log ""
done

log "=== done. Log: $LOG ==="
if [[ $DRY_RUN -eq 1 ]]; then
  log "Dry run only. Re-run without --dry-run to apply."
fi
