#!/usr/bin/env bash
#
# deploy-skills.sh
# Installs every skill from the two workflow repos into every harness. Nothing is listed by
# hand: whatever is in the repos is what ships.
#
#   dev-workflow/commands/<name>.md       ->  ~/.claude/commands/<name>.md            (Claude Code)
#   software-factory/commands/<name>.md   ->  ~/.cursor/skills/<name>/SKILL.md        (Cursor)
#                                         ->  ~/.agents/skills/<name>/SKILL.md        (Codex, unless a
#                                                                                      native version exists)
#   dev-workflow/codex/skills/<name>/     ->  ~/.codex/skills/<name>/                 (Codex-native skill)
#   software-factory/skills/<name>/       ->  ~/.claude/skills/<name>/, ~/.agents/skills/<name>/,
#                                             ~/.cursor/skills/<name>/
#   dev-workflow/scripts/factory-asks.sh  ->  ~/.local/bin/factory-asks              (helper on PATH)
#
# The SKILL.md render drops Claude-only frontmatter (argument-hint). A stale Codex fork in
# ~/.codex/skills/<name> of a skill with no native Codex version is moved to
# ~/.codex/skills-archive/ so Codex does not load two copies. Non-destructive: copies and
# moves only, never deletes. scripts/sync-skills.sh runs this after every install.
#
# Usage:
#   bash deploy-skills.sh --dry-run   # show what would happen, touch nothing
#   bash deploy-skills.sh             # apply
#
# DEV_ROOT (default ~/Developer) and HOME are honoured, so it can be pointed at a sandbox.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEV_ROOT="${DEV_ROOT:-$HOME/Developer}"
SF="$DEV_ROOT/software-factory"
CLAUDE_CMDS="$HOME/.claude/commands"
CLAUDE_SKILLS="$HOME/.claude/skills"
AGENTS_DIR="$HOME/.agents/skills"
CURSOR_DIR="$HOME/.cursor/skills"
CODEX_DIR="$HOME/.codex/skills"
CODEX_ARCHIVE="$HOME/.codex/skills-archive"
BIN_DIR="$HOME/.local/bin"

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

say() { if [[ $DRY_RUN -eq 1 ]]; then echo "  [dry-run] $*"; else echo "  $*"; fi; }

# Portable SKILL.md = the command file minus Claude-only frontmatter keys.
render_skill() { grep -v '^argument-hint:' "$1" || true; }

archive_codex_fork() {
  local name="$1" dest
  [[ -d "$CODEX_DIR/$name" ]] || return 0
  dest="$CODEX_ARCHIVE/$name-$(date +%Y%m%d-%H%M%S)"
  say "archive stale Codex fork $CODEX_DIR/$name -> $dest"
  if [[ $DRY_RUN -eq 0 ]]; then mkdir -p "$CODEX_ARCHIVE"; mv "$CODEX_DIR/$name" "$dest"; fi
}

# Commands: one markdown file each, from either repo.
for src in "$SCRIPT_DIR"/commands/*.md "$SF"/commands/*.md; do
  [[ -f "$src" ]] || continue
  name="$(basename "$src" .md)"
  echo "SKILL $name"
  say "copy -> $CLAUDE_CMDS/$name.md"
  [[ $DRY_RUN -eq 1 ]] || { mkdir -p "$CLAUDE_CMDS"; cp "$src" "$CLAUDE_CMDS/$name.md"; }

  targets=( "$CURSOR_DIR" )
  # A native Codex version owns the Codex side; do not ship a second copy to ~/.agents.
  [[ -d "$SCRIPT_DIR/codex/skills/$name" ]] || targets+=( "$AGENTS_DIR" )
  for dir in "${targets[@]}"; do
    say "render -> $dir/$name/SKILL.md"
    [[ $DRY_RUN -eq 1 ]] || { mkdir -p "$dir/$name"; render_skill "$src" > "$dir/$name/SKILL.md"; }
  done

  [[ -d "$SCRIPT_DIR/codex/skills/$name" ]] || archive_codex_fork "$name"
done

# Codex-native skills (a different format from the command file).
for src in "$SCRIPT_DIR"/codex/skills/*/; do
  [[ -d "$src" ]] || continue
  name="$(basename "$src")"
  echo "SKILL $name (Codex-native)"
  say "copy -> $CODEX_DIR/$name/"
  [[ $DRY_RUN -eq 1 ]] || { mkdir -p "$CODEX_DIR/$name"; cp -R "$src." "$CODEX_DIR/$name/"; }
done

# Folder skills owned by software-factory.
for src in "$SF"/skills/*/; do
  [[ -d "$src" ]] || continue
  name="$(basename "$src")"
  echo "SKILL $name (folder)"
  for dir in "$CLAUDE_SKILLS" "$AGENTS_DIR" "$CURSOR_DIR"; do
    say "copy -> $dir/$name/"
    [[ $DRY_RUN -eq 1 ]] || { mkdir -p "$dir/$name"; cp -R "$src." "$dir/$name/"; }
  done
  archive_codex_fork "$name"
done

# Helper scripts. Copied over the installed file, executable, so every harness finds the same one.
HELPERS=( "factory-asks.sh:factory-asks" )
for pair in "${HELPERS[@]}"; do
  src="$SCRIPT_DIR/scripts/${pair%%:*}"
  dest="$BIN_DIR/${pair##*:}"
  [[ -f "$src" ]] || { echo "FATAL: $src not found"; exit 1; }
  echo "HELPER ${pair##*:}"
  say "install -> $dest"
  [[ $DRY_RUN -eq 1 ]] || { mkdir -p "$BIN_DIR"; cp "$src" "$dest"; chmod 755 "$dest"; }
done

echo "done.$([[ $DRY_RUN -eq 1 ]] && echo ' Dry run only. Re-run without --dry-run to apply.')"
