#!/usr/bin/env bash
#
# install-output-styles.sh
# Makes ~/.claude/output-styles/<name>.md a symlink to output-styles/<name>.md in this repo,
# so the style is edited and reviewed here. Safe to re-run.
#
#   - Target dir missing: created.
#   - Already a symlink to the right file: prints ok, changes nothing.
#   - A regular file (or a symlink elsewhere) is moved aside first, next to it, as
#     <name>.backup-<HHMMSS>-<YYYY-MM-DD>.md, then the symlink is made.
#
# Never deletes anything. Exits non-zero only on a real error.
#
# Usage:
#   bash install-output-styles.sh                 # install into ~/.claude/output-styles
#   bash install-output-styles.sh --dir <path>    # install into another folder
#   bash install-output-styles.sh --dry-run       # report only, change nothing

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TARGET="$HOME/.claude/output-styles"
DRY_RUN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --dir) TARGET="${2:?--dir needs a path}"; shift ;;
    *) echo "unknown option: $1" >&2; exit 64 ;;
  esac
  shift
done

say()  { echo "  $*"; }
act()  { if [[ $DRY_RUN -eq 1 ]]; then echo "  would $*"; else echo "  doing $*"; fi; }
run()  { [[ $DRY_RUN -eq 1 ]] || "$@"; }

# Resolve a path (following links in its directory) to an absolute one; empty if the dir is missing.
abs() { local d; d="$(cd "$(dirname "$1")" 2>/dev/null && pwd -P)" || return 0; echo "$d/$(basename "$1")"; }

shopt -s nullglob
styles=("$REPO"/output-styles/*.md)
# The README documents the folder; it is not a style.
filtered=()
for f in ${styles[@]+"${styles[@]}"}; do [[ "$(basename "$f")" == "README.md" ]] || filtered+=("$f"); done
if [[ ${#filtered[@]} -eq 0 ]]; then echo "no output styles found in $REPO/output-styles" >&2; exit 1; fi

echo "== Output styles -> $TARGET"
if [[ ! -d "$TARGET" ]]; then
  act "create $TARGET"
  run mkdir -p "$TARGET"
fi

for src in "${filtered[@]}"; do
  name="$(basename "$src")"
  dest="$TARGET/$name"
  if [[ -L "$dest" && "$(abs "$(readlink "$dest")")" == "$src" ]]; then
    say "ok    $name"
    continue
  fi
  if [[ -e "$dest" || -L "$dest" ]]; then
    stem="${name%.md}"
    backup="$TARGET/$stem.backup-$(date +%H%M%S)-$(date +%Y-%m-%d).md"
    n=2
    while [[ -e "$backup" || -L "$backup" ]]; do
      backup="$TARGET/$stem.backup-$n-$(date +%H%M%S)-$(date +%Y-%m-%d).md"; n=$((n+1))
    done
    if [[ -L "$dest" ]]; then act "back up $name (symlink to $(readlink "$dest")) as $(basename "$backup")"
    else act "back up $name as $(basename "$backup")"; fi
    run mv "$dest" "$backup"
  fi
  act "link $name -> $src"
  run ln -s "$src" "$dest"
done
