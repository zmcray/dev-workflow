#!/usr/bin/env bash
# Tests for install-output-styles.sh. Temp dirs only; never touches ~/.claude.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/install-output-styles.sh"
REPO_STYLE="$HERE/../output-styles/exec-brief.md"
ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
backups() { find "$1" -maxdepth 1 -name 'exec-brief.backup-*' | wc -l | tr -d ' '; }
real() { (cd "$(dirname "$1")" && echo "$(pwd -P)/$(basename "$1")"); }
want="$(real "$REPO_STYLE")"

# 1. Fresh install creates the missing dir and a symlink that resolves to the repo file.
T="$ROOT/fresh/output-styles"
bash "$SCRIPT" --dir "$T" >/dev/null || fail "fresh install exited non-zero"
[[ -L "$T/exec-brief.md" ]] || fail "fresh: not a symlink"
[[ "$(real "$(readlink "$T/exec-brief.md")")" == "$want" ]] || fail "fresh: symlink does not resolve to repo file"
cmp -s "$T/exec-brief.md" "$REPO_STYLE" || fail "fresh: content differs"

# 2. Second run is a no-op: prints ok, no backup.
out="$(bash "$SCRIPT" --dir "$T")" || fail "rerun exited non-zero"
grep -q 'ok' <<<"$out" || fail "rerun: expected ok, got: $out"
[[ "$(backups "$T")" == 0 ]] || fail "rerun: a backup was made"

# 3. Existing regular file is backed up with identical content, then replaced by the symlink.
T="$ROOT/regular"; mkdir -p "$T"
printf 'my own edits\n' > "$T/exec-brief.md"
bash "$SCRIPT" --dir "$T" >/dev/null || fail "regular: exited non-zero"
[[ -L "$T/exec-brief.md" ]] || fail "regular: not replaced by symlink"
[[ "$(backups "$T")" == 1 ]] || fail "regular: expected exactly one backup"
b="$(find "$T" -maxdepth 1 -name 'exec-brief.backup-*')"
[[ "$(cat "$b")" == "my own edits" ]] || fail "regular: backup content differs"

# 6. Backup name ends with the date (before .md), never starts with it.
base="$(basename "$b")"
[[ "$base" =~ ^exec-brief\.backup-[0-9]{6}-[0-9]{4}-[0-9]{2}-[0-9]{2}\.md$ ]] || fail "backup name not date-last: $base"
[[ ! "$base" =~ ^[0-9]{4}- ]] || fail "backup name starts with a date: $base"

# 4. Existing symlink to another path is replaced and reported.
T="$ROOT/otherlink"; mkdir -p "$T"
printf 'elsewhere\n' > "$ROOT/elsewhere.md"
ln -s "$ROOT/elsewhere.md" "$T/exec-brief.md"
out="$(bash "$SCRIPT" --dir "$T")" || fail "otherlink: exited non-zero"
[[ "$(real "$(readlink "$T/exec-brief.md")")" == "$want" ]] || fail "otherlink: not repointed"
grep -qi 'backup' <<<"$out" || fail "otherlink: replacement not reported: $out"
[[ "$(backups "$T")" == 1 ]] || fail "otherlink: expected one backup"
[[ -f "$ROOT/elsewhere.md" ]] || fail "otherlink: the old target was touched"

# 5. --dry-run changes nothing (missing dir, and existing regular file).
T="$ROOT/dry/output-styles"
out="$(bash "$SCRIPT" --dry-run --dir "$T")" || fail "dry: exited non-zero"
[[ ! -e "$T" ]] || fail "dry: created the target dir"
grep -q 'would' <<<"$out" || fail "dry: expected 'would' lines: $out"
T="$ROOT/dry2"; mkdir -p "$T"; printf 'keep\n' > "$T/exec-brief.md"
bash "$SCRIPT" --dry-run --dir "$T" >/dev/null || fail "dry2: exited non-zero"
[[ -f "$T/exec-brief.md" && ! -L "$T/exec-brief.md" ]] || fail "dry2: file was changed"
[[ "$(backups "$T")" == 0 ]] || fail "dry2: a backup was made"

# Unknown option is a real error.
if bash "$SCRIPT" --nope >/dev/null 2>&1; then fail "unknown option should exit non-zero"; fi

echo "install-output-styles tests passed"
