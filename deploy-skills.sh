#!/usr/bin/env bash
#
# deploy-skills.sh
# Installs every skill in this repo into every harness. Nothing is listed by
# hand: whatever is in the repo is what ships.
#
#   dev-workflow/commands/<name>.md       ->  ~/.claude/commands/<name>.md            (Claude Code)
#                                         ->  ~/.cursor/skills/<name>/SKILL.md        (Cursor)
#                                         ->  ~/.agents/skills/<name>/SKILL.md        (Codex, unless a
#                                                                                      native version exists)
#   dev-workflow/codex/skills/<name>/     ->  ~/.codex/skills/<name>/                 (Codex-native skill)
#   dev-workflow/factory/skills/<name>/   ->  ~/.claude/skills/<name>/, ~/.agents/skills/<name>/,
#                                             ~/.cursor/skills/<name>/
#   dev-workflow/scripts/factory-asks.sh  ->  ~/.local/bin/factory-asks              (helper on PATH)
#
# The SKILL.md render drops Claude-only frontmatter (argument-hint). A stale Codex fork in
# ~/.codex/skills/<name> of a skill with no native Codex version is moved to
# ~/.codex/skills-archive/ so Codex does not load two copies.
#
# Manifest. Every file written under ~/.claude is recorded with its hash in
# ~/.claude/.skill-sync-manifest. That is how this script and scripts/sync-skills.sh tell a
# copy edited in place (hash changed since deploy) from one that is merely out of date:
#   - an installed Claude file about to be overwritten that was edited in place, or was never
#     deployed by this script, is first kept under ~/.claude/.skill-sync-archive/<stamp>/;
#   - a file deployed last time whose source is gone (a skill or command deleted or renamed
#     upstream) is retired: moved to the same archive, so a deletion actually takes effect.
# Copies and moves only, never deletes.
#
# Usage:
#   bash deploy-skills.sh --dry-run   # show what would happen, touch nothing
#   bash deploy-skills.sh             # apply
#
# DEV_ROOT (default ~/Developer) and HOME are honoured, so it can be pointed at a sandbox.
# Normally run by scripts/sync-skills.sh, which first captures in-place edits into the repos.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEV_ROOT="${DEV_ROOT:-$HOME/Developer}"
SF="$SCRIPT_DIR/factory"
CLAUDE_CMDS="$HOME/.claude/commands"
CLAUDE_SKILLS="$HOME/.claude/skills"
AGENTS_DIR="$HOME/.agents/skills"
CURSOR_DIR="$HOME/.cursor/skills"
CODEX_DIR="$HOME/.codex/skills"
CODEX_ARCHIVE="$HOME/.codex/skills-archive"
BIN_DIR="$HOME/.local/bin"
MANIFEST="$HOME/.claude/.skill-sync-manifest"
STAMP="$(date +%Y%m%d-%H%M%S)"
KEEP_DIR="$HOME/.claude/.skill-sync-archive/$STAMP"

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

say() { if [[ $DRY_RUN -eq 1 ]]; then echo "  [dry-run] $*"; else echo "  $*"; fi; }

# Portable SKILL.md = the command file minus Claude-only frontmatter keys.
render_skill() { grep -v '^argument-hint:' "$1" || true; }

hash_of() { shasum -a 1 "$1" | cut -d' ' -f1; }
# Hash recorded for an installed path at the last deploy (empty if none). Lines: "<sha>  <path>".
manifest_hash() {
  [[ -f "$MANIFEST" ]] || return 0
  awk -v p="$1" '{ h = $1; sub(/^[^ ]+  /, ""); if ($0 == p) { print h; exit } }' "$MANIFEST"
}

NEW_MANIFEST="$(mktemp)"
trap 'rm -f "$NEW_MANIFEST"' EXIT

# Keep an installed Claude file before it is overwritten, unless it is exactly what the last
# deploy wrote (then it is only out of date and safe to replace).
keep_if_edited() {
  local dest="$1" new="$2" m rel
  [[ -f "$dest" ]] || return 0
  cmp -s "$dest" "$new" && return 0
  m="$(manifest_hash "$dest")"
  [[ -n "$m" && "$(hash_of "$dest")" == "$m" ]] && return 0
  rel="${dest#"$HOME"/}"
  say "keep edited copy ~/$rel -> ${KEEP_DIR#"$HOME"/}/$rel"
  [[ $DRY_RUN -eq 1 ]] || { mkdir -p "$(dirname "$KEEP_DIR/$rel")"; cp -p "$dest" "$KEEP_DIR/$rel"; }
}

# Write one file into ~/.claude and record it in the manifest.
install_claude_file() {
  local src="$1" dest="$2"
  keep_if_edited "$dest" "$src"
  if [[ $DRY_RUN -eq 0 ]]; then
    mkdir -p "$(dirname "$dest")"; cp "$src" "$dest"
    printf '%s  %s\n' "$(hash_of "$dest")" "$dest" >> "$NEW_MANIFEST"
  else
    printf '%s  %s\n' "dry" "$dest" >> "$NEW_MANIFEST"
  fi
}

archive_codex_fork() {
  local name="$1" dest
  [[ -d "$CODEX_DIR/$name" ]] || return 0
  dest="$CODEX_ARCHIVE/$name-$STAMP"
  say "archive stale Codex fork $CODEX_DIR/$name -> $dest"
  if [[ $DRY_RUN -eq 0 ]]; then mkdir -p "$CODEX_ARCHIVE"; mv "$CODEX_DIR/$name" "$dest"; fi
}

# Commands: one markdown file each.
for src in "$SCRIPT_DIR"/commands/*.md; do
  [[ -f "$src" ]] || continue
  name="$(basename "$src" .md)"
  echo "SKILL $name"
  say "copy -> $CLAUDE_CMDS/$name.md"
  install_claude_file "$src" "$CLAUDE_CMDS/$name.md"

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

# Folder skills, kept under factory/skills/.
for src in "$SF"/skills/*/; do
  [[ -d "$src" ]] || continue
  src="${src%/}"; name="$(basename "$src")"
  echo "SKILL $name (folder)"
  say "copy -> $CLAUDE_SKILLS/$name/"
  while IFS= read -r f; do
    install_claude_file "$f" "$CLAUDE_SKILLS/$name/${f#"$src"/}"
  done < <(find "$src" -type f ! -name .DS_Store)
  for dir in "$AGENTS_DIR" "$CURSOR_DIR"; do
    say "copy -> $dir/$name/"
    [[ $DRY_RUN -eq 1 ]] || { mkdir -p "$dir/$name"; cp -R "$src/." "$dir/$name/"; }
  done
  archive_codex_fork "$name"
done

# Retire what the last deploy wrote under ~/.claude but the repos no longer have.
if [[ -f "$MANIFEST" ]]; then
  while IFS= read -r line; do
    p="${line#*  }"
    [[ -n "$p" && -f "$p" ]] || continue
    awk -v p="$p" '{ sub(/^[^ ]+  /, ""); if ($0 == p) { found = 1; exit } } END { exit !found }' "$NEW_MANIFEST" && continue
    rel="${p#"$HOME"/}"
    say "retire ~/$rel (removed upstream) -> ${KEEP_DIR#"$HOME"/}/retired/$rel"
    if [[ $DRY_RUN -eq 0 ]]; then
      mkdir -p "$(dirname "$KEEP_DIR/retired/$rel")"; mv "$p" "$KEEP_DIR/retired/$rel"
      # Remove the skill's folder only if moving its files left it empty.
      [[ "$(dirname "$p")" == "$CLAUDE_CMDS" ]] || rmdir "$(dirname "$p")" 2>/dev/null || true
    fi
  done < "$MANIFEST"
fi
[[ $DRY_RUN -eq 1 ]] || { mkdir -p "$(dirname "$MANIFEST")"; mv "$NEW_MANIFEST" "$MANIFEST"; }

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
