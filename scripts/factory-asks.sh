#!/usr/bin/env bash
#
# factory-asks.sh
# The night factory's one door to its asks (os.factory_asks on mcray-os): what a run needs
# from Zack, stored so Pulse can show it until he closes it. deploy-skills.sh installs this
# file as ~/.local/bin/factory-asks. Edit the source here, never the installed copy.
#
#   factory-asks check                                      is the writer token present and current?
#   factory-asks open <project_id>                          open asks for one Linear project
#   factory-asks upsert <ask.json | ->                      file or refresh one ask
#   factory-asks resolve <ask_id> <project_id> <run_id> <note>
#   factory-asks record-sync <project_id> <run_id> <asks_written>
#   factory-asks dry-run <open|upsert|resolve|record-sync> ...
#                                                           validate and print the request; send nothing
#
# An upsert file is one JSON object. Fields (the RPC's arguments without the p_ prefix):
#   linear_issue_id (issue UUID), issue_identifier (MCR-123), project_id (Linear project UUID,
#   from .linear-project.json), project_name, kind (check | human_step | follow_up), ask_key,
#   ask, prompt_md, steps, done_when, run_id; optional trigger_pr, where_to_look, wizard,
#   seen_again. The rules match factory_ask_upsert, and a broken ask is refused here, before
#   the token is read or anything is sent.
#
# The token lives only in the Keychain (service PULSE_FACTORY_WRITER_JWT, minted by the Pulse
# wizard scripts/wizards/MCR-2123-factory-writer-token.sh). It reaches curl on stdin (-K -),
# so it is never in a command line, in ps, or in any output. Output is the HTTP status and
# the returned status fields; `open` also prints one JSON row per ask.
#
# Exit codes: 0 ok; 1 refused here, nothing sent; 2 the server said no or could not be
# reached; 3 no usable token or a missing tool (the factory records a warning and goes on).
#
# Runs on macOS /bin/bash 3.2: no associative arrays, no ${x,,}, no mapfile.

set -uo pipefail

# Fixed on purpose: no environment override, so nothing can point the token at another host.
SUPABASE_URL="https://mtypgfwcebzsdlbuojef.supabase.co"
# Public by design (the publishable key ships in the Pulse client); not a secret.
SUPABASE_PUBLISHABLE_KEY="sb_publishable_Hu1RxVfMkKKS6MpZcUjdZw_O3qx0Y4D"
# Overridable only to test the missing-token path.
KEYCHAIN_SERVICE="${FACTORY_ASKS_KEYCHAIN_SERVICE:-PULSE_FACTORY_WRITER_JWT}"
RENEW_WARN_DAYS=14

UUID_RE='^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
RUN_ID_RE='^[0-9]{4}-[0-9]{2}-[0-9]{2}-[a-z0-9]+(-[a-z0-9]+)*-[0-9]{4}$'

TOKEN=""
TOKEN_NOTE=""
HTTP_CODE=""
RESP=""

usage() { sed -n '8,14p' "$0" | sed 's/^# \{0,1\}//'; }
die() { printf 'factory-asks: %s\n' "$2" >&2; exit "$1"; }

need_tools() {
  local t
  for t in "$@"; do
    command -v "$t" >/dev/null 2>&1 || die 3 "missing tool: $t (warn in the ledger and the status update, then go on)"
  done
}

# ── validation (mirrors factory_ask_upsert and friends; the RPC re-checks all of it) ──

# Shared jq definitions. Oniguruma regexes; lengths are code points, like char_length.
# The secret patterns copy public.prompt_text_has_secret.
read -r -d '' JQ_DEFS <<'JQ'
def ctl: "[\\x00-\\x1f\\x7f]";
def hidden: "[\\x{200b}-\\x{200f}\\x{202a}-\\x{202e}\\x{2066}-\\x{2069}\\x{feff}]";
def trimmed: sub("^\\s+"; "") | sub("\\s+$"; "");
def str: type == "string";
def oneline: str and (test(ctl) | not) and (test(hidden) | not);
def secret: str and test("\\bsk-[A-Za-z0-9_-]{20,}|\\bgh[pousr]_[A-Za-z0-9]{20,}|\\bgithub_pat_[A-Za-z0-9_]{20,}|\\bxox[abops]-[A-Za-z0-9-]{10,}|eyJ[A-Za-z0-9_-]{8,}\\.eyJ[A-Za-z0-9_-]{8,}|-----BEGIN [A-Z ]*PRIVATE KEY-----|\\bAKIA[0-9A-Z]{16}\\b|\\bsbp_[A-Za-z0-9]{20,}|\\bsb_secret_[A-Za-z0-9_-]{10,}|\\b[sr]k_(live|test)_[A-Za-z0-9]{16,}|postgres(ql)?://[^/\\s:@]+:[^@\\s]+@|\\bAIza[0-9A-Za-z_-]{35}\\b");
def uuid: str and test("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$");
def filled: str and (trimmed | length) > 0;
JQ

# jq program: prints one line per problem with the ask, nothing when it is fine.
read -r -d '' ASK_BODY <<'JQ'
if type != "object" then "the ask must be one JSON object"
else
  . as $a
  | ["linear_issue_id","issue_identifier","project_id","project_name","kind","ask_key","ask",
     "prompt_md","steps","done_when","run_id","trigger_pr","where_to_look","wizard","seen_again"] as $known
  | ($a.kind // "") as $kind
  | (($a.steps // []) | if type == "array" then . else [] end) as $steps
  | ( ($a | keys[] | select(. as $k | $known | index($k) | not) | "unknown field: \(.)"),
      (["linear_issue_id","issue_identifier","project_id","project_name","kind","ask_key","ask",
        "prompt_md","steps","done_when","run_id"][] | select($a[.] == null) | "missing field: \(.)"),

      (select($a.linear_issue_id != null and ($a.linear_issue_id | uuid | not)) | "linear_issue_id must be the issue UUID"),
      (select($a.project_id != null and ($a.project_id | uuid | not)) | "project_id must be the Linear project UUID"),
      (select($a.issue_identifier != null and (($a.issue_identifier | str and test("^[A-Z][A-Z0-9]*-[0-9]+$")) | not)) | "issue_identifier must look like MCR-123"),
      (select($a.project_name != null and (($a.project_name | str and (trimmed | length) >= 1 and (trimmed | length) <= 120) | not)) | "project_name must be 1 to 120 characters"),
      (select($a.run_id != null and (($a.run_id | str and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}-[a-z0-9]+(-[a-z0-9]+)*-[0-9]{4}$")) | not)) | "run_id must be <YYYY-MM-DD>-<lane>-<HHMM>"),
      (select($a.kind != null and ([ "check", "human_step", "follow_up" ] | index($kind) | not)) | "kind must be check, human_step or follow_up"),

      # KTD2: keys are rule-based per kind
      (select($a.ask_key != null) | $a.ask_key
        | select(
            (str | not)
            or ($kind == "human_step" and . != "gate")
            or ($kind == "check" and (test("^ac-[1-9][0-9]{0,2}$") | not))
            or ($kind == "follow_up"
                and ([ "decide-scope", "apply-migration", "restore-baseline", "unblock-dependency" ] | index($a.ask_key) | not)
                and ((test("^other-[a-z0-9]+(-[a-z0-9]+)*$") and length <= 30) | not)))
        | "ask_key breaks KTD2: human_step is gate, check is ac-<n>, follow_up is a listed slug or other-<slug> (at most 30 characters)"),

      # a check is filed for one PR and says where to look; nothing else has a PR
      (if $kind == "check" then
         (select((($a.trigger_pr | type) == "number" and $a.trigger_pr >= 1 and ($a.trigger_pr | floor) == $a.trigger_pr) | not) | "a check needs trigger_pr, the PR it was filed for"),
         (select(($a.where_to_look | filled) | not) | "a check needs where_to_look")
       else
         (select($a.trigger_pr != null) | "only a check carries trigger_pr")
       end),
      (select($a.where_to_look != null and (($a.where_to_look | str and length <= 500 and (test(hidden) | not)) | not)) | "where_to_look is text of at most 500 characters"),

      (select($a.wizard != null) | $a.wizard
        | select($kind == "check" or (str | not) or (test("^bash scripts/wizards/[A-Za-z0-9_.-]+\\.sh$") | not) or test("\\.\\."))
        | "wizard must be bash scripts/wizards/<file>.sh, on a human step or follow-up"),
      (select($a.wizard != null and ([ $steps[] | select(type == "object") | .action | select(type == "object" and .type == "run" and .value == $a.wizard) ] | length) == 0)
        | "a wizard is also one of the run steps"),

      (select($a.ask != null and (($a.ask | oneline and (trimmed | length) >= 1 and (trimmed | length) <= 300) | not)) | "ask is one line of 1 to 300 characters"),
      (select($a.prompt_md != null and (($a.prompt_md | filled and length <= 8192 and (test(hidden) | not)) | not)) | "prompt_md is required, at most 8192 characters, no hidden characters"),
      (select($a.seen_again != null and ($a.seen_again | type) != "boolean") | "seen_again is true or false"),

      # KTD14: the runbook
      (select($a.done_when != null and (($a.done_when | oneline and (trimmed | length) >= 1 and (trimmed | length) <= 300) | not)) | "runbook: done_when is one line of 1 to 300 characters"),
      (select($a.steps != null) | $a.steps
        | if type != "array" then "runbook: steps must be a JSON array"
          elif length < 1 or length > 8 then "runbook: steps must hold 1 to 8 steps (this one has \(length))"
          else
            to_entries[] | (.key + 1) as $n | .value
            | if type != "object" then "runbook: step \($n) is not an object"
              else
                ( (keys[] | select(. != "text" and . != "action") | "runbook: step \($n) has an unknown field: \(.)"),
                  (select((.text | oneline and filled and length <= 200) | not) | "runbook: step \($n) text is one line of 1 to 200 characters"),
                  (select(.action != null) | .action
                    | if (type != "object") or ((.type | str) | not) or ((.value | str) | not) then "runbook: step \($n) action is {type, value} with string values"
                      elif (keys - ["type", "value"]) != [] then "runbook: step \($n) action holds type and value, nothing else"
                      elif .type == "open" then
                        select((.value | length <= 2048 and test("^https://[^/?#@\\s\\x00-\\x1f\\x7f]+([/?#][^\\s\\x00-\\x1f\\x7f]*)?$") and (test(hidden) | not)) | not)
                        | "runbook: step \($n) open action takes an https:// URL"
                      elif .type == "run" then
                        select((.value | oneline and filled and length <= 300) | not) | "runbook: step \($n) run action is one command line of 1 to 300 characters"
                      elif .type == "copy" then
                        select((.value | oneline and filled and length <= 500) | not) | "runbook: step \($n) copy action is one line of 1 to 500 characters"
                      else "runbook: step \($n) action type is open, run or copy"
                      end)
                )
              end
          end),

      # never echo the match: say where, not what
      ( [ "ask", "prompt_md", "where_to_look", "done_when", "project_name" ][]
        | select($a[.] | secret) | "secret_detected in \(.)"),
      ( $steps | to_entries[] | (.key + 1) as $n | .value
        | select(type == "object")
        | select((.text | secret) or ((.action | type) == "object" and (.action.value | secret)))
        | "secret_detected in step \($n)")
    )
end
JQ
ASK_RULES="${JQ_DEFS}
${ASK_BODY}"

validate_ask() {  # validate_ask FILE -> prints problems, returns 1 if any
  local problems
  if ! jq -e . "$1" >/dev/null 2>&1; then
    printf 'refused: the ask is not valid JSON\n'
    return 1
  fi
  problems=$(jq -r "$ASK_RULES" "$1" 2>&1) || { printf 'refused: validator failed: %s\n' "$problems"; return 1; }
  if [[ -n "$problems" ]]; then
    printf '%s\n' "$problems" | sed 's/^/refused: /'
    return 1
  fi
  return 0
}

is_uuid() { [[ "$1" =~ $UUID_RE ]]; }
is_run_id() { [[ "$1" =~ $RUN_ID_RE ]]; }
has_ctl() { [[ "$1" =~ [[:cntrl:]] ]]; }

# ── the token ──

# Loads TOKEN from the Keychain and checks its expiry without printing it.
# Returns 0 with TOKEN_NOTE "ok, expires <date>" (plus a renewal warning when close),
# or 3 with TOKEN_NOTE saying what is wrong.
load_token() {
  local exp now days
  TOKEN=$(security find-generic-password -s "$KEYCHAIN_SERVICE" -w 2>/dev/null) || TOKEN=""
  if [[ -z "$TOKEN" ]]; then
    TOKEN_NOTE="missing: no Keychain entry ${KEYCHAIN_SERVICE} (run the Pulse wizard scripts/wizards/MCR-2123-factory-writer-token.sh)"
    return 3
  fi
  # base64url payload -> exp, decoded from stdin so the token stays off argv
  exp=$(printf '%s' "$TOKEN" | jq -Rr 'split(".")[1] // ""
      | gsub("-"; "+") | gsub("_"; "/")
      | . + ("=" * ((4 - length % 4) % 4) // "")
      | @base64d | fromjson | .exp // empty' 2>/dev/null) || exp=""
  if [[ ! "$exp" =~ ^[0-9]+$ ]]; then
    TOKEN=""
    TOKEN_NOTE="unreadable: the ${KEYCHAIN_SERVICE} entry is not a JWT with an expiry (re-run the wizard)"
    return 3
  fi
  now=$(date +%s)
  if (( exp <= now )); then
    TOKEN=""
    TOKEN_NOTE="expired on $(date -r "$exp" +%Y-%m-%d) (re-run the Pulse wizard scripts/wizards/MCR-2123-factory-writer-token.sh)"
    return 3
  fi
  days=$(( (exp - now) / 86400 ))
  TOKEN_NOTE="ok, expires $(date -r "$exp" +%Y-%m-%d)"
  if (( days < RENEW_WARN_DAYS )); then
    TOKEN_NOTE="${TOKEN_NOTE} (renew within ${days} days: re-run the Pulse wizard)"
  fi
  return 0
}

# ── the call ──

# rpc NAME JSON_BODY: POSTs to the RPC; sets HTTP_CODE and RESP. The token goes to curl on
# stdin and is cleared right after.
rpc() {
  local name="$1" body="$2" out
  out=$(mktemp "${TMPDIR:-/tmp}/factory-asks.XXXXXX") || die 2 "cannot create a temp file"
  HTTP_CODE=$(printf 'header = "Authorization: Bearer %s"\n' "$TOKEN" \
    | curl -sS --max-time 20 -o "$out" -w '%{http_code}' -K - \
        -X POST -H "apikey: ${SUPABASE_PUBLISHABLE_KEY}" \
        -H "Content-Type: application/json" -H "Accept: application/json" \
        --data-raw "$body" "${SUPABASE_URL}/rest/v1/rpc/${name}" 2>/dev/null) || HTTP_CODE="000"
  TOKEN=""
  RESP=$(cat "$out" 2>/dev/null)
  rm -f "$out"
}

# Prints the result line; exits 2 on anything but 2xx. PostgREST errors carry the RPC's
# named exception in .message, which never echoes a secret.
report() {
  local fields="$1" msg
  if [[ "$HTTP_CODE" =~ ^2 ]]; then
    printf 'HTTP %s %s\n' "$HTTP_CODE" "$(printf '%s' "$RESP" | jq -r "$fields" 2>/dev/null)"
    return 0
  fi
  if [[ "$HTTP_CODE" == "000" ]]; then
    msg="could not reach ${SUPABASE_URL}"
  else
    msg=$(printf '%s' "$RESP" | jq -r '.message // .error // "no message"' 2>/dev/null | head -c 300)
  fi
  printf 'HTTP %s error: %s\n' "$HTTP_CODE" "$msg"
  exit 2
}

# ── building each request (validation first, so a refusal never reads the token) ──

REQ_NAME=""
REQ_BODY=""
ASK_TMP=""

cleanup() { [[ -n "$ASK_TMP" ]] && rm -f "$ASK_TMP"; return 0; }
trap cleanup EXIT

build_request() {
  local cmd="${1:-}"
  shift || true
  case "$cmd" in
    open)
      [[ $# -eq 1 ]] || die 1 "usage: factory-asks open <project_id>"
      is_uuid "$1" || die 1 "refused: project_id must be the Linear project UUID"
      REQ_NAME="factory_asks_open"
      REQ_BODY=$(jq -cn --arg p "$1" '{p_project_id: $p}')
      ;;
    upsert)
      [[ $# -eq 1 ]] || die 1 "usage: factory-asks upsert <ask.json | ->"
      local src="$1"
      if [[ "$src" == "-" ]]; then
        ASK_TMP=$(mktemp "${TMPDIR:-/tmp}/factory-ask.XXXXXX") || die 2 "cannot create a temp file"
        cat > "$ASK_TMP"
        src="$ASK_TMP"
      fi
      [[ -r "$src" ]] || die 1 "refused: cannot read $src"
      validate_ask "$src" || { printf 'nothing sent.\n'; exit 1; }
      REQ_NAME="factory_ask_upsert"
      REQ_BODY=$(jq -c 'with_entries(.key |= "p_" + .)' "$src")
      ;;
    resolve)
      [[ $# -eq 4 ]] || die 1 "usage: factory-asks resolve <ask_id> <project_id> <run_id> <note>"
      is_uuid "$1" || die 1 "refused: ask_id must be the ask's UUID (from factory-asks open)"
      is_uuid "$2" || die 1 "refused: project_id must be the Linear project UUID"
      is_run_id "$3" || die 1 "refused: run_id must be <YYYY-MM-DD>-<lane>-<HHMM>"
      if [[ ${#4} -lt 1 || ${#4} -gt 300 ]] || has_ctl "$4"; then die 1 "refused: note is one line of 1 to 300 characters"; fi
      if ! jq -en --arg n "$4" "${JQ_DEFS}"' $n | secret | not' >/dev/null; then
        die 1 "refused: secret_detected in note"
      fi
      REQ_NAME="factory_ask_resolve"
      REQ_BODY=$(jq -cn --arg i "$1" --arg p "$2" --arg r "$3" --arg n "$4" \
        '{p_id: $i, p_project_id: $p, p_run_id: $r, p_note: $n}')
      ;;
    record-sync)
      [[ $# -eq 3 ]] || die 1 "usage: factory-asks record-sync <project_id> <run_id> <asks_written>"
      is_uuid "$1" || die 1 "refused: project_id must be the Linear project UUID"
      is_run_id "$2" || die 1 "refused: run_id must be <YYYY-MM-DD>-<lane>-<HHMM>"
      if [[ ! "$3" =~ ^[0-9]{1,5}$ ]] || (( 10#$3 > 10000 )); then
        die 1 "refused: asks_written must be 0 to 10000"
      fi
      REQ_NAME="factory_ask_sync_record"
      REQ_BODY=$(jq -cn --arg p "$1" --arg r "$2" --argjson n "$((10#$3))" \
        '{p_project_id: $p, p_run_id: $r, p_asks_written: $n}')
      ;;
    *)
      usage >&2
      exit 1
      ;;
  esac
}

# ── main ──

need_tools jq curl security

cmd="${1:-}"
[[ $# -gt 0 ]] && shift

case "$cmd" in
  check)
    if load_token; then TOKEN=""; printf 'token: %s\n' "$TOKEN_NOTE"; exit 0; fi
    printf 'token: %s\n' "$TOKEN_NOTE"
    exit 3
    ;;
  dry-run)
    build_request "$@"
    printf 'DRY RUN: nothing sent.\n'
    printf 'POST %s/rest/v1/rpc/%s\n' "$SUPABASE_URL" "$REQ_NAME"
    printf 'apikey: %s\n' "$SUPABASE_PUBLISHABLE_KEY"
    printf 'Authorization: Bearer <Keychain %s, never printed>\n' "$KEYCHAIN_SERVICE"
    printf 'Content-Type: application/json\n\n'
    printf '%s' "$REQ_BODY" | jq .
    if load_token; then
      TOKEN=""
      printf '\ntoken: %s\n' "$TOKEN_NOTE"
      exit 0
    fi
    printf '\ntoken: %s\n' "$TOKEN_NOTE"
    printf 'A real call would exit 3: record the warning in the ledger and the status update, then go on.\n'
    exit 3
    ;;
  open|upsert|resolve|record-sync)
    build_request "$cmd" "$@"
    if ! load_token; then
      printf 'token: %s\n' "$TOKEN_NOTE"
      exit 3
    fi
    [[ "$TOKEN_NOTE" == *renew* ]] && printf 'token: %s\n' "$TOKEN_NOTE"
    rpc "$REQ_NAME" "$REQ_BODY"
    case "$cmd" in
      open)
        report '"open=\(length)"'
        printf '%s' "$RESP" | jq -c '.[]'
        ;;
      upsert|resolve) report '"status=\(.status) id=\(.id) generation=\(.generation)"' ;;
      record-sync) report '"synced run_id=\(.run_id) asks_written=\(.asks_written)"' ;;
    esac
    ;;
  ""|-h|--help|help)
    usage
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac
