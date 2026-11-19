#!/bin/bash
#
# Tests for scripts/factory-asks.sh and doc guards for the asks rules in commands/factory.md.
# The helper is only ever run in dry-run mode against fixture folders: nothing is sent.
# Runs on macOS /bin/bash 3.2 and on CI's bash: no associative arrays, no mapfile.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HELPER="$ROOT/scripts/factory-asks.sh"
RULES="$ROOT/commands/factory.md"
CI_FILE="$ROOT/.github/workflows/ci.yml"
FAILS=0

ok() { printf 'ok   %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1"; FAILS=$((FAILS + 1)); }
# has NAME TEXT REGEX / lacks NAME TEXT REGEX (extended regex, case-sensitive)
has() { if printf '%s\n' "$2" | grep -Eq -- "$3"; then ok "$1"; else fail "$1"; fi; }
lacks() { if printf '%s\n' "$2" | grep -Eq -- "$3"; then fail "$1"; else ok "$1"; fi; }
# is NAME ACTUAL EXPECTED
is() { if [[ "$2" == "$3" ]]; then ok "$1"; else fail "$1 (got $2, want $3)"; fi; }
count() { printf '%s\n' "$1" | grep -Ec -- "$2"; }
# section START END: the rulebook from the line starting with START up to the line starting with END
section() {
  awk -v s="$1" -v e="$2" 'index($0, s) == 1 { on = 1 } on && index($0, e) == 1 { exit } on { print }' "$RULES"
}

TMP=$(mktemp -d "${TMPDIR:-/tmp}/factory-asks-test.XXXXXX") || exit 1
trap 'rm -rf "$TMP"' EXIT

# ── open-all: one request per project found in a link file ──

A=11111111-1111-4111-8111-111111111111
B=22222222-2222-4222-8222-222222222222
C=33333333-3333-4333-8333-333333333333
FX="$TMP/dev"
mkdir -p "$FX/alpha" "$FX/mono/apps/one" "$FX/mono/apps/two" "$FX/bare" "$FX/broken" "$FX/noid" "$FX/deep/a"
printf '{"id":"%s","name":"Alpha"}\n' "$A" > "$FX/alpha/.linear-project.json"
printf '{"id":"%s","name":"One"}\n' "$B" > "$FX/mono/apps/one/.linear-project.json"
printf '{"id":"%s","name":"Alpha again"}\n' "$A" > "$FX/mono/apps/two/.linear-project.json"
printf 'not json\n' > "$FX/broken/.linear-project.json"
printf '{"name":"No id"}\n' > "$FX/noid/.linear-project.json"
printf '{"id":"%s"}\n' "$C" > "$FX/deep/a/.linear-project.json"
printf 'no link file here\n' > "$FX/bare/README.md"

out=$(/bin/bash "$HELPER" dry-run open-all "$FX" 2>"$TMP/err"); rc=$?
err=$(cat "$TMP/err")
has "open-all dry run exits 0, or 3 with no token" "$rc" '^(0|3)$'
has "open-all dry run says nothing was sent" "$out" '^DRY RUN: nothing sent\.$'
is "open-all sends one request per project" "$(count "$out" '^POST .*/rpc/factory_asks_open$')" 2
is "open-all asks for the root link file's project once" "$(count "$out" "\"p_project_id\": \"$A\"")" 1
is "open-all asks for the nested link file's project" "$(count "$out" "\"p_project_id\": \"$B\"")" 1
has "open-all names the link file a project came from" "$out" "$FX/mono/apps/one/\.linear-project\.json"
lacks "open-all does not scan two levels down" "$out" "$C"
is "a broken link file is skipped with one line" "$(count "$err" "skipped $FX/broken/\.linear-project\.json")" 1
is "a link file with no project id is skipped with one line" "$(count "$err" "skipped $FX/noid/\.linear-project\.json")" 1
is "nothing else is reported on stderr" "$(printf '%s\n' "$err" | grep -c .)" 2
lacks "no token is ever printed" "$out$err" 'eyJ[A-Za-z0-9_-]{8,}\.'

mkdir -p "$TMP/empty/repo"
/bin/bash "$HELPER" dry-run open-all "$TMP/empty" >/dev/null 2>&1
is "open-all with no link file is refused" "$?" 1

out=$(/bin/bash "$HELPER" dry-run open "$A" 2>/dev/null); rc=$?
has "open still takes one project" "$rc" '^(0|3)$'
is "open still sends one request" "$(count "$out" '^POST .*/rpc/factory_asks_open$')" 1
/bin/bash "$HELPER" dry-run open not-a-uuid >/dev/null 2>&1
is "open still refuses a bad project id" "$?" 1
has "usage lists open-all" "$(/bin/bash "$HELPER" help 2>&1)" 'factory-asks open-all'

# ── doc guards: the sweep covers every project ──

step1b=$(section "## Step 1b" "## Step 2")
item3=$(printf '%s\n' "$step1b" | grep -E '^3\. ')
has "Step 1b lists with open-all" "$step1b" 'factory-asks open-all'
has "Step 1b item 3 resolves in every project" "$item3" 'every project'
has "Step 1b item 3 resolves with the ask's own project id" "$item3" "ask's own project"
sweep_line=$(grep -E '^Sweep: ' "$RULES")
has "the Sweep line names asks resolved in other projects" "$sweep_line" 'asks resolved in other projects'
has "CI runs this file" "$(cat "$CI_FILE")" '^ +- run: bash scripts/factory-asks\.test\.sh$'

if [[ "$FAILS" -gt 0 ]]; then
  printf '\n%s failed\n' "$FAILS"
  exit 1
fi
printf '\nall passed\n'
