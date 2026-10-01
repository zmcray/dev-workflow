#!/usr/bin/env bash
#
# sync-skills.sh
# Keeps this Mac on the approved skills and workflow rules, and proposes its own edits for
# review. Run by the com.mcray.skill-sync launch agent (see install-skill-sync.sh), by
# setup-factory-machine.sh, by /factory before a night shift, and by hand. Safe to re-run.
#
# For ~/Developer/dev-workflow and ~/Developer/software-factory (main checkouts on main only):
#
#   1. Capture. An installed Claude copy edited in place since the last deploy (its hash no
#      longer matches ~/.claude/.skill-sync-manifest) is copied back into its repo. A skill
#      written straight into ~/.claude/skills/<name>/ (not gstack's, not in skill-sync.ignore,
#      never deployed by us) is adopted into software-factory/skills/<name>/; a loose
#      ~/.claude/commands/<name>.md into software-factory/commands/.
#   2. Install what is approved. Fast-forward to origin/main (merged changes only), keeping
#      local edits (--autostash). If a local edit collides with an approved change, the
#      approved version wins for that file only and the edit is kept in a named stash.
#   3. Propose what is not. Any local change left (edits, new files, local commits) becomes one
#      commit on this Mac's branch sync/<host>, built in a temporary index so the working tree
#      and main are untouched, secret-scanned with gitleaks (fail closed: dev-workflow is
#      public), pushed, and opened as a pull request. Merging it is the approval. This job
#      never merges and never pushes to main.
#   4. Deploy. deploy-skills.sh re-installs every skill from the repos, keeping any edited copy
#      it would overwrite and retiring skills removed upstream.
#
# One macOS notification per run, only when something needs Zack (a new proposal, a rule-file
# change, a secret hit, a collision, a failure). Log: ~/Library/Logs/skill-sync.log
# The last line of every run is "status: ok" or "status: attention".
#
# Preview: SKILL_SYNC_DRY=1 writes nothing (no capture, install, push, PR or deploy) and logs
# what it would do. Test hooks: DEV_ROOT, HOME, GH, GITLEAKS, SKILL_SYNC_NO_NOTIFY=1,
# SKILL_SYNC_HOST (branch name suffix).

set -uo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

DEV_ROOT="${DEV_ROOT:-$HOME/Developer}"
WF="$DEV_ROOT/dev-workflow"
SF="$DEV_ROOT/software-factory"
GH="${GH:-gh}"
GITLEAKS="${GITLEAKS:-gitleaks}"
DRY="${SKILL_SYNC_DRY:-0}"
NO_NOTIFY="${SKILL_SYNC_NO_NOTIFY:-0}"
IGNORE_FILE="$WF/scripts/skill-sync.ignore"
MANIFEST="$HOME/.claude/.skill-sync-manifest"
LOCK="$HOME/Library/Caches/com.mcray.skill-sync.lock"
SUBJECT_PREFIX="chore(sync): edits from"

host="${SKILL_SYNC_HOST:-$(scutil --get LocalHostName 2>/dev/null || hostname -s)}"
HOST="$(printf '%s' "$host" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9-' '-' | sed 's/-*$//')"
BRANCH="sync/$HOST"
# Files that change how every agent behaves: called out by name in the notification and PR.
RULES_RE='(^|/)(AGENTS\.md|AGENTS\.workflow\.md|CLAUDE\.md|SORT\.md|DISPATCH\.md)$|^commands/factory\.md$'

DRY_TAG=""; [[ "$DRY" == "1" ]] && DRY_TAG="[dry] "
log() { echo "$(date '+%Y-%m-%d %H:%M') $*"; }
ALERTS=""
alert() { log "$*"; ALERTS="${ALERTS:+$ALERTS; }$*"; }

# ── lock ──────────────────────────────────────────────────────────────────
mkdir -p "$(dirname "$LOCK")"
if ! mkdir "$LOCK" 2>/dev/null; then
  if [[ -n "$(find "$LOCK" -maxdepth 0 -mmin +120 2>/dev/null)" ]]; then
    rmdir "$LOCK" 2>/dev/null; mkdir "$LOCK" 2>/dev/null || { log "lock busy, exiting"; log "status: attention"; exit 0; }
  else
    log "another sync is running, exiting"; log "status: attention"; exit 0
  fi
fi
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

# ── repo eligibility ──────────────────────────────────────────────────────
# Only the main checkout, on main, with no merge, rebase or unresolved conflict in flight.
eligible() {
  local p="$1" r gd branch
  r="$(basename "$p")"
  if [[ ! -d "$p/.git" ]]; then alert "$r: not cloned (run setup-factory-machine.sh)"; return 1; fi
  branch="$(git -C "$p" symbolic-ref --short -q HEAD)"
  if [[ "$branch" != "main" ]]; then alert "$r is on '${branch:-detached}', not main: not synced"; return 1; fi
  gd="$(git -C "$p" rev-parse --absolute-git-dir)"
  if [[ -e "$gd/MERGE_HEAD" || -d "$gd/rebase-merge" || -d "$gd/rebase-apply" ]]; then
    alert "$r has a merge or rebase in progress: not synced"; return 1
  fi
  if [[ -n "$(git -C "$p" ls-files -u)" ]]; then
    alert "$r has unresolved conflicts: not synced"; return 1
  fi
  return 0
}

OK_WF=0; OK_SF=0
eligible "$WF" && OK_WF=1
eligible "$SF" && OK_SF=1

# ── 1. capture ────────────────────────────────────────────────────────────
is_ignored() { [[ -f "$IGNORE_FILE" ]] && grep -v '^[[:space:]]*#' "$IGNORE_FILE" | grep -qxF "$1"; }
hash_of() { shasum -a 1 "$1" | cut -d' ' -f1; }
manifest_hash() {
  [[ -f "$MANIFEST" ]] || return 0
  awk -v p="$1" '{ h = $1; sub(/^[^ ]+  /, ""); if ($0 == p) { print h; exit } }' "$MANIFEST"
}
# True if the last deploy wrote anything at or under this path.
manifest_owns() {
  [[ -f "$MANIFEST" ]] || return 1
  awk -v p="$1" '{ sub(/^[^ ]+  /, ""); if ($0 == p || index($0, p "/") == 1) { found = 1; exit } } END { exit !found }' "$MANIFEST"
}
repo_of() { case "$1" in "$WF"/*) echo "$WF" ;; *) echo "$SF" ;; esac; }

# Copy an installed file back to its repo source if it was edited since the last deploy.
capture_file() {
  local inst="$1" src="$2" m repo
  m="$(manifest_hash "$inst")"
  if [[ -n "$m" ]]; then
    [[ "$(hash_of "$inst")" == "$m" ]] && return 0        # untouched since deploy
    [[ -f "$src" ]] || return 0                           # removed upstream; deploy retires it
  else
    [[ -f "$src" ]] && return 0                           # not ours to judge yet (no record)
  fi
  [[ -f "$src" ]] && cmp -s "$inst" "$src" && return 0
  repo="$(repo_of "$src")"
  if [[ -f "$src" ]] && { ! git -C "$repo" diff --quiet -- "$src" || [[ -n "$(git -C "$repo" ls-files --others -- "$src")" ]]; }; then
    alert "${src#"$DEV_ROOT"/} was edited in the repo AND in its installed copy; the repo copy wins, the installed copy is kept in ~/.claude/.skill-sync-archive"
    return 0
  fi
  [[ "$DRY" == "1" ]] || { mkdir -p "$(dirname "$src")"; cp "$inst" "$src"; }
  log "${DRY_TAG}captured in-place edit: ${src#"$DEV_ROOT"/}"
}

if [[ ! -f "$MANIFEST" ]]; then
  log "no deploy manifest yet: in-place edits are captured from the next run on (the first deploy keeps any edited copy in ~/.claude/.skill-sync-archive)"
else
  if [[ $OK_WF -eq 1 ]]; then
    for src in "$WF"/commands/*.md; do [[ -f "$src" ]] && capture_file "$HOME/.claude/commands/$(basename "$src")" "$src"; done
  fi
  if [[ $OK_SF -eq 1 ]]; then
    for src in "$SF"/commands/*.md; do [[ -f "$src" ]] && capture_file "$HOME/.claude/commands/$(basename "$src")" "$src"; done
    for src in "$SF"/skills/*/; do
      [[ -d "$src" ]] || continue
      src="${src%/}"; inst="$HOME/.claude/skills/$(basename "$src")"
      [[ -d "$inst" && ! -L "$inst" ]] || continue
      while IFS= read -r f; do capture_file "$f" "$src/${f#"$inst"/}"; done < <(find "$inst" -type f ! -name .DS_Store)
    done
  fi
fi

# Adopt skills written straight into ~/.claude. gstack installs its skills as folders holding a
# SKILL.md link into ~/.claude/skills/gstack; those, and anything a deploy ever wrote (a skill
# removed upstream), are never adopted.
if [[ $OK_SF -eq 1 ]]; then
  for d in "$HOME"/.claude/skills/*/; do
    [[ -d "$d" ]] || continue
    d="${d%/}"; name="$(basename "$d")"
    [[ -L "$d" ]] && continue
    case "$name" in _*|.*|gstack) continue ;; esac
    [[ -e "$HOME/.claude/skills/gstack/$name" ]] && continue
    [[ -f "$d/SKILL.md" && ! -L "$d/SKILL.md" ]] || continue
    [[ -d "$SF/skills/$name" ]] && continue
    manifest_owns "$d" && continue
    is_ignored "$name" && continue
    if [[ "$DRY" != "1" ]]; then
      mkdir -p "$SF/skills/$name"; cp -R "$d/." "$SF/skills/$name/"
      find "$SF/skills/$name" -name .DS_Store -delete
    fi
    log "${DRY_TAG}adopted skill $name into software-factory/skills"
  done
  for f in "$HOME"/.claude/commands/*.md; do
    [[ -f "$f" && ! -L "$f" ]] || continue
    name="$(basename "$f" .md)"
    [[ -f "$WF/commands/$name.md" || -f "$SF/commands/$name.md" ]] && continue
    manifest_owns "$f" && continue
    is_ignored "$name" && continue
    [[ "$DRY" == "1" ]] || { mkdir -p "$SF/commands"; cp "$f" "$SF/commands/$name.md"; }
    log "${DRY_TAG}adopted command $name into software-factory/commands"
  done
fi

# ── 2 and 3, per repo ─────────────────────────────────────────────────────
repo_slug() {
  git -C "$1" remote get-url origin 2>/dev/null | sed -E 's#^(git@github\.com:|https://github\.com/)##; s#\.git$##'
}
collision_msg() { echo "skill-sync collision $HOST $(date '+%Y-%m-%d %H:%M')"; }

install_approved() {
  local p="$1" r before after out n f blob coll sha msg ref
  r="$(basename "$p")"
  before="$(git -C "$p" rev-parse HEAD)"
  n="$(git -C "$p" rev-list --count HEAD..origin/main)"
  [[ "$n" -eq 0 ]] && { log "$r: up to date"; return 0; }
  [[ "$DRY" == "1" ]] && { log "$r: ${DRY_TAG}would install $n approved commit(s)"; return 0; }

  # Untracked files that origin/main now tracks. Identical: this Mac's own merged proposal, so
  # drop the local copy. Different: a collision, so move it into a named stash first.
  coll=()
  while IFS= read -r f; do
    blob="$(git -C "$p" rev-parse -q --verify "origin/main:$f" 2>/dev/null)" || continue
    if [[ "$(git -C "$p" hash-object -- "$p/$f")" == "$blob" ]]; then rm -f -- "$p/$f"; else coll+=( "$f" ); fi
  done < <(git -C "$p" ls-files --others --exclude-standard)
  if [[ ${#coll[@]} -gt 0 ]]; then
    msg="$(collision_msg)"
    if git -C "$p" stash push -q -u -m "$msg" -- "${coll[@]}"; then
      alert "$r: new local file(s) ${coll[*]} collide with approved ones; approved installed, yours kept in stash \"$msg\""
    else
      alert "$r: could not set aside colliding new file(s) ${coll[*]}; approved changes not installed"; return 1
    fi
  fi

  if ! out="$(git -C "$p" pull -q --rebase --autostash origin main 2>&1)"; then
    [[ -d "$(git -C "$p" rev-parse --absolute-git-dir)/rebase-merge" ]] && git -C "$p" rebase --abort 2>/dev/null
    alert "$r: could not install approved changes ($(printf '%s' "$out" | grep -v '^hint:' | head -n2 | tr '\n' ' '))"
    return 1
  fi

  # A local edit that collided with an approved change: git leaves the file conflicted and the
  # whole autostash in the stash. Restore only the conflicted files to the approved version,
  # keep every other local edit in place, and give the stash a name.
  coll=()
  while IFS= read -r f; do [[ -n "$f" ]] && coll+=( "$f" ); done < <(git -C "$p" diff --name-only --diff-filter=U)
  if [[ ${#coll[@]} -gt 0 ]]; then
    git -C "$p" checkout -q HEAD -- "${coll[@]}"
    git -C "$p" reset -q
    sha="$(git -C "$p" rev-parse -q --verify refs/stash)"
    msg="$(collision_msg)"
    # Rename the "autostash" entry: git will not record the same commit twice in a row, so drop
    # the unnamed entry first, then store the commit (still in the object store) by name.
    ref="$(git -C "$p" stash list --format='%gd %H %gs' | awk -v s="$sha" '$2 == s && $3 == "autostash" { print $1; exit }')"
    if [[ -n "$ref" ]] && git -C "$p" stash drop -q "$ref" && git -C "$p" stash store -m "$msg" "$sha"; then
      alert "$r: your edit to ${coll[*]} collided with an approved change; approved version installed, your edit kept in stash \"$msg\""
    else
      alert "$r: your edit to ${coll[*]} collided with an approved change; approved version installed, your edit is stash commit $sha (git stash store -m keep $sha)"
    fi
  fi
  after="$(git -C "$p" rev-parse HEAD)"
  log "$r: installed approved ${before:0:7}..${after:0:7}"
}

propose_local() {
  local p="$1" r idx tree commit prev base files n rules slug pr body list tip
  r="$(basename "$p")"
  if [[ -z "$(git -C "$p" status --porcelain)" && "$(git -C "$p" rev-list --count origin/main..HEAD)" -eq 0 ]]; then
    log "$r: no local edits"; return 0
  fi

  # The working tree as a commit, through a throwaway index: the real index, working tree and
  # main stay exactly as they are.
  idx="$(mktemp)"
  cp "$(git -C "$p" rev-parse --absolute-git-dir)/index" "$idx"
  GIT_INDEX_FILE="$idx" git -C "$p" add -A
  tree="$(GIT_INDEX_FILE="$idx" git -C "$p" write-tree)"
  rm -f "$idx"
  [[ -n "$tree" ]] || { alert "$r: could not snapshot local edits"; return 1; }

  [[ "$tree" == "$(git -C "$p" rev-parse 'origin/main^{tree}')" ]] && { log "$r: local edits match main"; return 0; }

  slug="$(repo_slug "$p")"
  prev="$(git -C "$p" rev-parse -q --verify "refs/remotes/origin/$BRANCH^{tree}" 2>/dev/null)"
  if [[ "$tree" == "$prev" ]]; then
    pr="$("$GH" pr list -R "$slug" --head "$BRANCH" --state open --json url --jq '.[0].url' 2>/dev/null)"
    if [[ -z "$pr" ]]; then
      alert "$r: edits on $HOST were proposed but the pull request is closed unmerged. Reopen it, or discard them with 'git -C $p stash'"
    else
      log "$r: proposal unchanged ($pr)"
    fi
    return 0
  fi
  # Someone pushed to this Mac's proposal branch (a review fix): never overwrite their work.
  tip="$(git -C "$p" log -1 --format=%s "refs/remotes/origin/$BRANCH" 2>/dev/null)"
  if [[ -n "$tip" && "$tip" != "$SUBJECT_PREFIX $HOST" ]]; then
    alert "$r: $BRANCH has a commit not made by the sync ('$tip'); merge or close that pull request first, nothing pushed"
    return 1
  fi

  commit="$(git -C "$p" commit-tree "$tree" -p HEAD -m "$SUBJECT_PREFIX $HOST")"
  [[ -n "$commit" ]] || { alert "$r: could not build the proposal commit (git identity set?)"; return 1; }
  base="$(git -C "$p" merge-base origin/main "$commit")"
  files="$(git -C "$p" diff --name-only "$base" "$commit")"
  n="$(printf '%s\n' "$files" | grep -c .)"
  rules="$(printf '%s\n' "$files" | grep -E "$RULES_RE" | tr '\n' ' ' | sed 's/ $//')"

  # Secret scan, fail closed. Binary files are not scanned by gitleaks, so none are proposed.
  if git -C "$p" diff --numstat "$base" "$commit" | grep -q $'^-\t-\t'; then
    alert "$r: local edits include a binary file, not proposed (commit it yourself if intended)"; return 1
  fi
  if ! command -v "$GITLEAKS" >/dev/null 2>&1; then
    alert "$r: gitleaks not installed, edits not proposed (brew install gitleaks)"; return 1
  fi
  "$GITLEAKS" git --no-banner --redact --exit-code 3 \
    --log-opts="--diff-merges=first-parent origin/main..$commit" "$p" >/dev/null 2>&1
  case $? in
    0) ;;
    3) alert "$r: possible secret in this Mac's edits, NOT proposed. See: gitleaks git --redact --log-opts=origin/main..$commit $p"; return 1 ;;
    *) alert "$r: secret scan failed, edits not proposed"; return 1 ;;
  esac

  if [[ "$DRY" == "1" ]]; then
    log "$r: ${DRY_TAG}would propose $n file(s) on $BRANCH: $(printf '%s' "$files" | tr '\n' ' ')"
    return 0
  fi

  if ! git -C "$p" push -q --force-with-lease="refs/heads/$BRANCH" origin "$commit:refs/heads/$BRANCH" 2>/dev/null; then
    alert "$r: could not push proposal to $BRANCH"; return 1
  fi
  pr="$("$GH" pr list -R "$slug" --head "$BRANCH" --state open --json url --jq '.[0].url' 2>/dev/null)"
  if [[ -z "$pr" ]]; then
    # shellcheck disable=SC2016  # the backticks are markdown, not command substitution
    list="$(printf '%s\n' "$files" | sed 's/^/- `/; s/$/`/')"
    body="Edits made on **$HOST**, proposed automatically by \`scripts/sync-skills.sh\`. Merging this pull request is the approval: both Macs install it on their next sync, and \`/factory\` installs it before the next night shift. Close it to reject; the edits stay on $HOST until discarded.

Files:
$list
${rules:+
**Rule files changed** (every agent follows these): $rules}"
    pr="$("$GH" pr create -R "$slug" --base main --head "$BRANCH" --title "sync: edits from $HOST" --body "$body" 2>/dev/null)"
    [[ -n "$pr" ]] || { alert "$r: proposal pushed to $BRANCH but the pull request did not open"; return 1; }
  fi
  alert "$r: $n file(s) from $HOST up for review${rules:+ (rule files: $rules)} $pr"
}

for p in "$WF" "$SF"; do
  r="$(basename "$p")"
  if [[ "$p" == "$WF" && $OK_WF -eq 0 ]] || [[ "$p" == "$SF" && $OK_SF -eq 0 ]]; then continue; fi
  if ! git -C "$p" fetch -q --prune origin 2>/dev/null; then
    alert "$r: fetch failed (offline?), not synced"; continue
  fi
  install_approved "$p"
  propose_local "$p"
done

# ── 4. deploy ─────────────────────────────────────────────────────────────
# Only from repos that are on main: never install a feature branch's skills.
if [[ $OK_WF -eq 0 || $OK_SF -eq 0 ]]; then
  alert "skills not redeployed until both repos are back on main"
elif [[ "$DRY" == "1" ]]; then
  log "skills: ${DRY_TAG}would deploy"
elif out="$(DEV_ROOT="$DEV_ROOT" bash "$WF/deploy-skills.sh" 2>&1)"; then
  log "skills: deployed"
  printf '%s\n' "$out" | grep -E '^  (keep edited copy|retire) ' | while IFS= read -r l; do log "skills:$l"; done
  printf '%s\n' "$out" | grep -q '^  keep edited copy' && alert "an edited installed skill was replaced by the repo version; your copy is in ~/.claude/.skill-sync-archive"
else
  alert "skills: deploy failed (run bash $WF/deploy-skills.sh to see why)"
fi

# ── notify ────────────────────────────────────────────────────────────────
if [[ -n "$ALERTS" && "$NO_NOTIFY" != "1" ]]; then
  # Quotes and backslashes would break the AppleScript string.
  # shellcheck disable=SC1003
  msg="$(printf '%s' "$ALERTS" | tr '"\\' "' " | cut -c1-400)"
  osascript -e "display notification \"$msg\" with title \"Skill sync\"" >/dev/null 2>&1 || true
fi
log "status: $([[ -n "$ALERTS" ]] && echo attention || echo ok)"
exit 0
