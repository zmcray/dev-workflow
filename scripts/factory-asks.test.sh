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
# Text reaches grep as a here-string, never through a pipe: with pipefail, grep -q leaving
# early on a match would fail the pipe and the guard with it.
has() { if grep -Eq -- "$3" <<<"$2"; then ok "$1"; else fail "$1"; fi; }
lacks() { if grep -Eq -- "$3" <<<"$2"; then fail "$1"; else ok "$1"; fi; }
# In a pattern write a backtick bare, never \`: GNU grep reads that as "start of text".
# is NAME ACTUAL EXPECTED
is() { if [[ "$2" == "$3" ]]; then ok "$1"; else fail "$1 (got $2, want $3)"; fi; }
count() { grep -Ec -- "$2" <<<"$1"; }
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
D=abcdefab-cdef-4abc-8def-abcdefabcdef
D_UPPER=ABCDEFAB-CDEF-4ABC-8DEF-ABCDEFABCDEF
FX="$TMP/dev"
mkdir -p "$FX/alpha" "$FX/mono/apps/one" "$FX/mono/apps/two" "$FX/bare" "$FX/broken" "$FX/noid" "$FX/deep/a" "$FX/lower" "$FX/upper"
printf '{"id":"%s","name":"Alpha"}\n' "$A" > "$FX/alpha/.linear-project.json"
printf '{"id":"%s","name":"One"}\n' "$B" > "$FX/mono/apps/one/.linear-project.json"
printf '{"id":"%s","name":"Alpha again"}\n' "$A" > "$FX/mono/apps/two/.linear-project.json"
printf 'not json\n' > "$FX/broken/.linear-project.json"
printf '{"name":"No id"}\n' > "$FX/noid/.linear-project.json"
printf '{"id":"%s"}\n' "$C" > "$FX/deep/a/.linear-project.json"
printf 'no link file here\n' > "$FX/bare/README.md"
printf '{"id":"%s"}\n' "$D" > "$FX/lower/.linear-project.json"
printf '{"id":"%s"}\n' "$D_UPPER" > "$FX/upper/.linear-project.json"

out=$(/bin/bash "$HELPER" dry-run open-all "$FX" 2>"$TMP/err"); rc=$?
err=$(cat "$TMP/err")
has "open-all dry run exits 0, or 3 with no token" "$rc" '^(0|3)$'
has "open-all dry run says nothing was sent" "$out" '^DRY RUN: nothing sent\.$'
is "open-all sends one request per project" "$(count "$out" '^POST .*/rpc/factory_asks_open$')" 3
is "the same project id in another letter case is listed once" "$(printf '%s\n' "$out" | grep -ic "\"p_project_id\": \"$D\"")" 1
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
has "Step 1b item 3 resolves in every project" "$item3" 'covers every project with an open ask, not only tonight.s'
has "Step 1b item 3 resolves with the ask's own project id" "$item3" "ask's own project"
has "in another project a run only resolves" "$item3" 'In another project a run only resolves: it never releases a migration park, upserts an ask or changes an issue there'
has "a migration park is released in this project only" "$item3" 'Release any migration park of this project that a standing approval now covers'
lacks "no unscoped release of a migration park" "$item3" 'Release any migration park a standing approval'
item2=$(printf '%s\n' "$step1b" | grep -E '^2\. ')
has "a partial open-all still gives rows to work with" "$item2" 'On a non-zero exit that still printed rows, use those rows'
has "a partial open-all names the projects it could not list" "$item2" 'name each project it could not list under Notes in the status update'
has "a partial open-all does not hold back the sync marker" "$item2" 'still record the sync marker: it is about this run.s own writes'
has "the sync marker depends on this run's own writes only" "$(cat "$RULES")" 'When no upsert or resolve tonight ended in exit 2 or 3, run'
sweep_line=$(grep -E '^Sweep: ' "$RULES")
has "the Sweep line names asks resolved in other projects" "$sweep_line" 'asks resolved in other projects'
has "CI runs this file" "$(cat "$CI_FILE")" '^ +- run: bash scripts/factory-asks\.test\.sh$'

# ── doc guards: the Morning check files Bugs for plain defects, at the widths an app promises ──

mc=$(section "## Morning check" "## Asks")
has "an objective row: content cut off, hidden, overlapping or overflowing" "$mc" 'content cut off, hidden, overlapping or overflowing'
has "an objective row: a number in the wrong format" "$mc" 'a number in the wrong format'
has "an objective row: a console error from that page" "$mc" 'a console error from that page'
has "an objective row is re-checked on the default branch" "$mc" 'Re-check it on the current default branch'
has "an objective row is searched for a duplicate" "$mc" 'for a duplicate'
has "one Bug per root cause" "$mc" 'one Bug per root cause'
has "the Bug goes in the epic's hardening milestone with its labels" "$mc" "epic's \`hardening\` milestone, the screenshot, \`Bug\`, one \`flow:\*\` label and a priority"
has "an objective row stays out of the ask" "$mc" 'stays out of the ask'
has "a taste row goes to Zack in the one ask" "$mc" '^\*\*The one ask\.\*\* Taste and cannot-check rows go to Zack together.*other-morning-check'
has "a taste row is a difference with nothing broken" "$mc" 'the build and the canvas differ and nothing is broken'
has "taste is every flagged row that is not objective" "$mc" '^- \*\*Taste:\*\* every other flagged row'
has "a pass stops filing after 5 Bugs and lists the rest" "$mc" 'After 5 Bugs in a pass, file no more: the rest are only listed'
has "the check reads its widths from the link file" "$mc" '`check\.widths`'
has "with no widths set it keeps today's two" "$mc" 'with none set, desktop 1280x800 and phone 390x844'
has "a width the key leaves out is never flagged" "$mc" 'Never open or flag a screen at a width the key leaves out'
has "rules/setup.md documents factory.check.widths" "$(cat "$ROOT/rules/setup.md")" 'factory\.check\.widths'

OLD_RULE='never reopens an issue or files a Bug|never files a Bug|flags, and Zack decides|file a Bug if it is wrong|file a Bug for a real problem|[Oo]nly what looks wrong or cannot be opened|only a flagged or uncheckable'
left=$(cd "$ROOT" && grep -rnE "$OLD_RULE" commands factory rules | grep -v '^factory/DECISIONS\.md:.*~~')
is "no file still says the check never files a Bug" "$left" ""

decisions=$(cat "$ROOT/factory/DECISIONS.md")
d033=$(printf '%s\n' "$decisions" | awk '/^## D-033:/ { on = 1 } /^## D-034:/ { on = 0 } on')
has "D-033's old clause is struck through with a pointer" "$d033" '~~[^~]*never reopens an issue or files a Bug itself[^~]*~~[^.]*D-036'
has "D-033's width clause is struck through with a pointer" "$d033" '~~at desktop and phone width~~[^.]*D-036'
has "D-033's what-reaches-Zack clause is struck through with a pointer" "$d033" '~~Only what looks wrong or cannot be opened[^~]*~~[^.]*D-036'
has "the decision log records the Bug-filing check" "$decisions" '^## D-036: .*Bug'

# ── doc guards: the four-way test, and "wait" is not an ask ──

ask=$(section "**Is it an ask?**" "**Every ask hangs")
has "the test names Zack's hands on a physical device" "$ask" "Zack's hands\*\* on a physical device"
has "the test names a secret or sign-in in his name" "$ask" 'a secret or sign-in in his name'
has "the test names his money" "$ask" 'his money'
has "the test names a product judgment only he can make" "$ask" 'a product judgment only he can make'
has "a wait or leave-as-is decision with nothing blocked is not an ask" "$ask" '"wait" or "leave as is" with nothing blocked behind it: no ask'
has "a deferred decision is noted on the issue and the status update" "$ask" 'on the issue and on the status update.s `Deferred decisions:` line'
has "decisions still carry the recommended answer first" "$ask" 'Recommended: <option>, because <one line>'
has "disposable infrastructure is still kept by default" "$ask" 'is kept by default'
# The section on main before this rule landed: 6 lines, 300 words. It may shrink, never grow.
ask_lines=$(printf '%s\n' "$ask" | grep -c .)
ask_words=$(printf '%s\n' "$ask" | wc -w | tr -d ' ')
if [[ "$ask_lines" -le 6 && "$ask_words" -le 300 ]]; then ok "Is it an ask? is no longer than before"; else fail "Is it an ask? grew ($ask_lines lines, $ask_words words; limit 6 and 300)"; fi
template=$(section "Factory <date> (<lane>, run:<run_id>): <d> done" "## Morning review")
has "the status update template carries Deferred decisions" "$template" '^Deferred decisions: '

# ── doc guards: an old ask keeps its own row; the weekly review holds only sweep rows ──

rules=$(cat "$RULES")
r5=$(section "**What closes an ask (R5).**" "**Weekly review.**")
wr=$(section "**Weekly review.**" "**Stale asks.**")
item4=$(printf '%s\n' "$step1b" | grep -E '^4\. ')
lacks "R5 no longer resolves an ask for its age" "$r5" '[Aa]ged'
has "R5 resolves a weekly review whose items are all closed or have their own ask" "$r5" '^- this project.s `other-weekly-review` follow-up whose every listed item is Done, Canceled or has its own open ask'
has "Step 1b item 4 is still the human-step pass" "$item4" 'Upsert human steps'
lacks "Step 1b item 4 no longer skips an old ask" "$item4" '7 days'
lacks "Step 1b item 4 no longer skips an issue in a weekly review" "$item4" '[Ww]eekly review'
lacks "an issue in the open weekly review can get an ask again" "$rules" 'In the open weekly review'
lacks "no rule folds an aged ask anywhere" "$rules" '[Aa]ged ask|aged_resolved|as aged'
has "the weekly review takes only sweep rows" "$wr" '^- \*\*What goes in\.\*\* Only sweep rows: every stale-started or merged-but-open row whose issue has not been updated in 7 days\.'
lacks "the weekly review no longer takes asks by age" "$wr" 'first seen more than 7 days ago'
has "an ask stays its own row however old" "$wr" 'An ask stays its own row however old it is'
has "a week with no sweep rows files no weekly review" "$wr" 'No sweep rows: file none'
has "an old-rule item stays listed, worded as it was" "$wr" '^- \*\*When\.\*\* .*an item it already lists that is not a sweep row stays listed, worded as it was, until it has its own open ask or its issue is Done or Canceled'
has "R5 resolves only this project's migration-park step" "$r5" '^- this project.s `human_step` on a migration park'
d031=$(printf '%s\n' "$decisions" | awk '/^## D-031:/ { on = 1 } /^## D-032:/ { on = 0 } on')
has "D-031's aged-ask clause is struck through with a pointer" "$d031" '~~[^~]*Asks older than 7 days[^~]*~~[^.]*D-037'
has "the decision log records that an ask keeps its own row" "$decisions" '^## D-037: .*own row'

if [[ "$FAILS" -gt 0 ]]; then
  printf '\n%s failed\n' "$FAILS"
  exit 1
fi
printf '\nall passed\n'
