#!/usr/bin/env bash
#
# deploy-skills.sh
# Ships the portable build skills to every harness from one source file each.
#
#   commands/<name>.md  ->  ~/.claude/commands/<name>.md        (Claude Code)
#                       ->  ~/.agents/skills/<name>/SKILL.md    (Codex)
#                       ->  ~/.cursor/skills/<name>/SKILL.md    (Cursor; it did not pick up ~/.agents/skills)
#
# The SKILL.md copy drops Claude-only frontmatter (argument-hint). A stale per-harness fork
# in ~/.codex/skills/<name> is moved to ~/.codex/skills-archive/ so Codex does not load two
# copies. Non-destructive: copies and moves only, never deletes.
#
# Usage:
#   bash deploy-skills.sh --dry-run   # show what would happen, touch nothing
#   bash deploy-skills.sh             # apply

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORTABLE=( factory packets caspian )
CLAUDE_DIR="$HOME/.claude/commands"
AGENTS_DIR="$HOME/.agents/skills"
CURSOR_DIR="$HOME/.cursor/skills"
CODEX_DIR="$HOME/.codex/skills"
CODEX_ARCHIVE="$HOME/.codex/skills-archive"

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

say() { if [[ $DRY_RUN -eq 1 ]]; then echo "  [dry-run] $*"; else echo "  $*"; fi; }

# Portable SKILL.md = the command file minus Claude-only frontmatter keys.
render_skill() { grep -v '^argument-hint:' "$1"; }

for name in "${PORTABLE[@]}"; do
  src="$SCRIPT_DIR/commands/$name.md"
  [[ -f "$src" ]] || { echo "FATAL: $src not found"; exit 1; }
  echo "SKILL $name"

  say "copy -> $CLAUDE_DIR/$name.md"
  [[ $DRY_RUN -eq 1 ]] || cp "$src" "$CLAUDE_DIR/$name.md"

  for dir in "$AGENTS_DIR" "$CURSOR_DIR"; do
    say "render -> $dir/$name/SKILL.md"
    if [[ $DRY_RUN -eq 0 ]]; then
      mkdir -p "$dir/$name"
      render_skill "$src" > "$dir/$name/SKILL.md"
    fi
  done

  if [[ -d "$CODEX_DIR/$name" ]]; then
    dest="$CODEX_ARCHIVE/$name-$(date +%Y%m%d-%H%M%S)"
    say "archive stale Codex fork $CODEX_DIR/$name -> $dest"
    if [[ $DRY_RUN -eq 0 ]]; then mkdir -p "$CODEX_ARCHIVE"; mv "$CODEX_DIR/$name" "$dest"; fi
  fi
done

echo "done.$([[ $DRY_RUN -eq 1 ]] && echo ' Dry run only. Re-run without --dry-run to apply.')"
