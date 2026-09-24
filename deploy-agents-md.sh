#!/usr/bin/env bash
#
# deploy-agents-md.sh
# Deploys the canonical AGENTS.md workflow block into each repo under ~/Developer,
# and repoints CLAUDE.md to import AGENTS.md so Claude Code reads the same source.
#
# Sources of truth (all siblings of this script):
#   AGENTS.workflow.md            the canonical workflow block (injected into every repo)
#   templates/AGENTS.md.template  the AGENTS.md scaffold ({{REPO}} + {{CANONICAL_WORKFLOW}})
#   templates/CLAUDE.md.template  the CLAUDE.md @AGENTS.md import file
# Edit those, re-run this script, and every repo re-syncs. Repo-specific context above
# the block is preserved across re-runs.
#
# Non-destructive: copies/edits only. Backs up any CLAUDE.md it replaces to the central
# backups/ folder beside this script (never inside a repo). Never deletes. Skips repos
# not present in ~/Developer.
#
# Usage:
#   bash deploy-agents-md.sh --dry-run    # show what would happen, touch nothing
#   bash deploy-agents-md.sh              # apply

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOW_FILE="$SCRIPT_DIR/AGENTS.workflow.md"
AGENTS_TEMPLATE="$SCRIPT_DIR/templates/AGENTS.md.template"
CLAUDE_TEMPLATE="$SCRIPT_DIR/templates/CLAUDE.md.template"
DEV_DIR="$HOME/Developer"
LOG="$SCRIPT_DIR/deploy-$(date +%Y%m%d-%H%M%S).log"
# Central backups dir. CLAUDE.md backups land here (out of the repos) so they never show
# up as uncommitted noise in a repo's working tree.
BACKUP_DIR="$SCRIPT_DIR/backups"

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

# Auto-discover every git repo directly under ~/Developer. No hardcoded list to maintain,
# so new repos are covered automatically. A repo is skipped if it is in EXCLUDE, is not a
# git repo, or contains a .agents-skip file (drop an empty .agents-skip in any repo you do
# not want the build workflow injected into... e.g. third-party clones).
EXCLUDE=( dev-workflow )
is_excluded() { local n="$1"; for e in "${EXCLUDE[@]}"; do [[ "$n" == "$e" ]] && return 0; done; return 1; }

BEGIN_MARK="<!-- BEGIN CANONICAL WORKFLOW"
END_MARK="<!-- END CANONICAL WORKFLOW -->"

log()  { echo "$*" | tee -a "$LOG"; }
act()  { if [[ $DRY_RUN -eq 1 ]]; then log "  [dry-run] $*"; else eval "$2"; log "  $1"; fi; }

[[ -f "$WORKFLOW_FILE" ]]   || { echo "FATAL: canonical block not found at $WORKFLOW_FILE"; exit 1; }
[[ -f "$AGENTS_TEMPLATE" ]] || { echo "FATAL: AGENTS template not found at $AGENTS_TEMPLATE"; exit 1; }
[[ -f "$CLAUDE_TEMPLATE" ]] || { echo "FATAL: CLAUDE template not found at $CLAUDE_TEMPLATE"; exit 1; }

log "=== deploy-agents-md.sh $([[ $DRY_RUN -eq 1 ]] && echo '(DRY RUN)') ==="
log "Canonical block: $WORKFLOW_FILE"
log "Developer dir:   $DEV_DIR"
log ""

# --- Skill drift check: commands/ and codex/skills/ sources vs their deployed copies ---
# Skills deploy by copy (see README), so a live copy edited in place (~/.claude/commands,
# ~/.codex/skills) silently diverges from source here — and the next source edit either
# clobbers or misses those changes. Warn on any divergence with the direction (which side
# is newer) so the fix is obvious. Warn-only: this script never copies skills; reconcile,
# then run deploy-skills.sh (portable skills) or the README's cp commands (the rest).
check_skill_drift() {
  local src dst drift=0
  log "--- skill drift check (source vs deployed) ---"
  while IFS='|' read -r src dst; do
    [[ -f "$src" ]] || continue
    if [[ ! -f "$dst" ]]; then
      drift=1; log "DRIFT: $src has no deployed copy at $dst — deploy it (see README)"
      continue
    fi
    if ! cmp -s "$src" "$dst"; then
      drift=1
      if [[ "$dst" -nt "$src" ]]; then
        log "DRIFT: deployed $dst is NEWER than source — sync it back first: cp \"$dst\" \"$src\""
      else
        log "DRIFT: source $src is newer than deployed — redeploy: cp \"$src\" \"$dst\""
      fi
    fi
  done < <(
    for f in "$SCRIPT_DIR"/commands/*.md; do
      echo "$f|$HOME/.claude/commands/$(basename "$f")"
    done
    for f in "$SCRIPT_DIR"/caspian/*.md; do
      echo "$f|$HOME/Developer/dev-workflow/caspian/$(basename "$f")"
    done
    for f in "$SCRIPT_DIR"/codex/skills/*/SKILL.md; do
      echo "$f|$HOME/.codex/skills/$(basename "$(dirname "$f")")/SKILL.md"
    done
  )
  # Portable skills (deploy-skills.sh) also live in ~/.agents/skills (Codex) and ~/.cursor/skills (Cursor),
  # rendered without Claude-only frontmatter, so compare against the same rendering.
  local name rendered
  for name in factory packets caspian; do
    src="$SCRIPT_DIR/commands/$name.md"
    [[ -f "$src" ]] || continue
    for dst in "$HOME/.agents/skills/$name/SKILL.md" "$HOME/.cursor/skills/$name/SKILL.md"; do
    if [[ ! -f "$dst" ]]; then
      drift=1; log "DRIFT: $src has no Codex/Cursor copy at $dst — run deploy-skills.sh"; continue
    fi
    rendered="$(grep -v '^argument-hint:' "$src")"
    if [[ "$rendered" != "$(cat "$dst")" ]]; then
      drift=1
      if [[ "$dst" -nt "$src" ]]; then
        log "DRIFT: deployed $dst is NEWER than source — fold its edits into $src, then run deploy-skills.sh"
      else
        log "DRIFT: source $src is newer than $dst — run deploy-skills.sh"
      fi
    fi
    done
  done
  [[ $drift -eq 0 ]] && log "Skill sources and deployed copies are in sync."
  log ""
}

check_skill_drift

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

# Render templates/AGENTS.md.template for a repo: substitute {{REPO}} and inject the
# canonical block at the {{CANONICAL_WORKFLOW}} line. Keeps AGENTS.workflow.md the single source.
render_agents_template() {
  local repo="$1"
  awk -v repo="$repo" -v blockfile="$WORKFLOW_FILE" '
    BEGIN { while ((getline line < blockfile) > 0) blk = blk line "\n" }
    {
      gsub(/\{\{REPO\}\}/, repo)
      if ($0 ~ /\{\{CANONICAL_WORKFLOW\}\}/) { printf "%s", blk }
      else { print }
    }
  ' "$AGENTS_TEMPLATE"
}

shopt -s nullglob
for dir in "$DEV_DIR"/*/; do
  dir="${dir%/}"
  repo="$(basename "$dir")"
  if [[ ! -d "$dir/.git" ]]; then
    log "SKIP $repo (not a git repo)"
    continue
  fi
  if is_excluded "$repo"; then
    log "SKIP $repo (excluded)"
    continue
  fi
  if [[ -f "$dir/.agents-skip" ]]; then
    log "SKIP $repo (.agents-skip present)"
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
  elif [[ -f "$claude" ]] && ! grep -q "@AGENTS.md" "$claude" && [[ $(grep -vcE '^\s*$' "$claude") -gt 1 ]]; then
    # Migration case: an existing CLAUDE.md carries real repo context. Preserve it as the
    # header (minus any standalone 'Issue tracker:' line, now in the block) + canonical block.
    if [[ $DRY_RUN -eq 1 ]]; then
      log "  [dry-run] AGENTS.md created (header migrated from CLAUDE.md) + canonical block"
    else
      { grep -vE '^\*\*Issue tracker:\*\*' "$claude"; printf '\n'; cat "$WORKFLOW_FILE"; } > "$agents"
      log "  AGENTS.md created (header migrated from CLAUDE.md) + canonical block"
    fi
  else
    # Fresh repo: render the AGENTS.md template (scaffold header + injected canonical block).
    if [[ $DRY_RUN -eq 1 ]]; then
      log "  [dry-run] AGENTS.md created from templates/AGENTS.md.template"
    else
      render_agents_template "$repo" > "$agents"
      log "  AGENTS.md created from templates/AGENTS.md.template"
    fi
  fi

  # --- CLAUDE.md -> import AGENTS.md ---
  if [[ -f "$claude" ]] && grep -q "@AGENTS.md" "$claude"; then
    log "  CLAUDE.md already imports AGENTS.md (left as-is)"
  else
    if [[ -f "$claude" ]]; then
      bak="$BACKUP_DIR/${repo}-CLAUDE.md.$(date +%Y%m%d-%H%M%S).bak"
      act "CLAUDE.md backed up to backups/$(basename "$bak")" "mkdir -p \"$BACKUP_DIR\"; cp \"$claude\" \"$bak\""
    fi
    if [[ $DRY_RUN -eq 1 ]]; then
      log "  [dry-run] CLAUDE.md rewritten from templates/CLAUDE.md.template"
    else
      cp "$CLAUDE_TEMPLATE" "$claude"
      log "  CLAUDE.md rewritten from templates/CLAUDE.md.template"
    fi
  fi
  log ""
done

log "=== done. Log: $LOG ==="
if [[ $DRY_RUN -eq 1 ]]; then
  log "Dry run only. Re-run without --dry-run to apply."
fi
