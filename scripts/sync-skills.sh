#!/usr/bin/env bash
#
# sync-skills.sh
# Keeps this Mac on the approved skills and workflow rules, and proposes its own edits for
# review. Run by the com.mcray.skill-sync launch agent (see install-skill-sync.sh), by /factory
# before a night shift, and by hand. Safe to re-run.
#
# For ~/Developer/dev-workflow and ~/Developer/software-factory (main checkouts on main only):
#
#   1. Capture. An edit made to an installed copy (~/.claude/commands/<name>.md,
#      ~/.claude/skills/<name>/) is copied back into its repo. A skill written straight into
#      ~/.claude/skills/<name>/ (not gstack's, not in skill-sync.ignore) is adopted into
#      software-factory/skills/<name>/; a loose ~/.claude/commands/<name>.md into
#      software-factory/commands/.
#   2. Install what is approved. Fast-forward to origin/main (merged changes only), keeping
#      local edits (--autostash). If a local edit collides with an approved change, the
#      approved version wins on disk and the edit stays in the stash.
#   3. Propose what is not. Any local change left (edits, new files, local commits) becomes one
#      commit on this Mac's branch sync/<host>, built in a temporary index so the working tree
#      and main are untouched, secret-scanned with gitleaks (fail closed: dev-workflow is
#      public), pushed, and opened as a pull request. Merging it is the approval. This job
#      never merges and never pushes to main.
#   4. Deploy. deploy-skills.sh re-installs every skill from the repos.
#
# One macOS notification per run, only when something needs Zack (a new proposal, a rule-file
# change, a secret hit, a collision, a failure). Log: ~/Library/Logs/skill-sync.log
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
LOCK="${TMPDIR:-/tmp}/com.mcray.skill-sync.lock"

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
if ! mkdir "$LOCK" 2>/dev/null; then
  if [[ -n "$(find "$LOCK" -maxdepth 0 -mmin +120 2>/dev/null)" ]]; then
    rmdir "$LOCK" 2>/dev/null; mkdir "$LOCK" 2>/dev/null || { log "lock busy, exiting"; exit 0; }
  else
    log "another sync is running, exiting"; exit 0
  fi
fi
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

# ── repo eligibility ──────────────────────────────────────────────────────
# Only the main checkout, on main, with no merge or rebase in flight.
eligible() {
  local p="$1" r gd branch
  r="$(basename "$p")"
  if [[ ! -d "$p/.git" ]]; then log "$r: not cloned, skipped (run setup-factory-machine.sh)"; return 1; fi
  branch="$(git -C "$p" symbolic-ref --short -q HEAD)"
  if [[ "$branch" != "main" ]]; then alert "$r is on '${branch:-detached}', not main: not synced"; return 1; fi
  gd="$(git -C "$p" rev-parse --absolute-git-dir)"
  if [[ -e "$gd/MERGE_HEAD" || -d "$gd/rebase-merge" || -d "$gd/rebase-apply" ]]; then
    alert "$r has a merge or rebase in progress: not synced"; return 1
  fi
  return 0
}

OK_WF=0; OK_SF=0
eligible "$WF" && OK_WF=1
eligible "$SF" && OK_SF=1

# ── 1. capture ────────────────────────────────────────────────────────────
is_ignored() { [[ -f "$IGNORE_FILE" ]] && grep -v '^[[:space:]]*#' "$IGNORE_FILE" | grep -qxF "$1"; }

# An installed command that differs from its source and is newer was edited in place.
capture_command() {
  local src="$1" inst
  inst="$HOME/.claude/commands/$(basename "$1")"
  [[ -f "$inst" && ! -L "$inst" ]] || return 0
  if ! cmp -s "$inst" "$src" && [[ "$inst" -nt "$src" ]]; then
    [[ "$DRY" == "1" ]] || cp "$inst" "$src"
    log "${DRY_TAG}captured in-place edit: $(basename "$src")"
  fi
}

# Same for a folder skill, file by file (new files included; deletions are not captured).
capture_folder() {
  local src="${1%/}" name inst f rel
  name="$(basename "$src")"; inst="$HOME/.claude/skills/$name"
  [[ -d "$inst" && ! -L "$inst" ]] || return 0
  while IFS= read -r f; do
    rel="${f#"$inst"/}"
    [[ "$(basename "$rel")" == .DS_Store ]] && continue
    if [[ ! -f "$src/$rel" ]] || { ! cmp -s "$f" "$src/$rel" && [[ "$f" -nt "$src/$rel" ]]; }; then
      [[ "$DRY" == "1" ]] || { mkdir -p "$(dirname "$src/$rel")"; cp "$f" "$src/$rel"; }
      log "${DRY_TAG}captured in-place edit: $name/$rel"
    fi
  done < <(find "$inst" -type f)
}

if [[ $OK_WF -eq 1 ]]; then
  for src in "$WF"/commands/*.md; do [[ -f "$src" ]] && capture_command "$src"; done
fi
if [[ $OK_SF -eq 1 ]]; then
  for src in "$SF"/commands/*.md; do [[ -f "$src" ]] && capture_command "$src"; done
  for src in "$SF"/skills/*/; do [[ -d "$src" ]] && capture_folder "$src"; done

  # Adopt skills written straight into ~/.claude/skills. gstack installs its skills as folders
  # holding a SKILL.md link into ~/.claude/skills/gstack; those are never adopted.
  for d in "$HOME"/.claude/skills/*/; do
    [[ -d "$d" ]] || continue
    d="${d%/}"; name="$(basename "$d")"
    [[ -L "$d" ]] && continue
    case "$name" in _*|.*|gstack) continue ;; esac
    [[ -e "$HOME/.claude/skills/gstack/$name" ]] && continue
    [[ -f "$d/SKILL.md" && ! -L "$d/SKILL.md" ]] || continue
    [[ -d "$SF/skills/$name" ]] && continue
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
    is_ignored "$name" && continue
    [[ "$DRY" == "1" ]] || { mkdir -p "$SF/commands"; cp "$f" "$SF/commands/$name.md"; }
    log "${DRY_TAG}adopted command $name into software-factory/commands"
  done
fi

# ── 2 and 3, per repo ─────────────────────────────────────────────────────
repo_slug() {
  git -C "$1" remote get-url origin 2>/dev/null | sed -E 's#^(git@github\.com:|https://github\.com/)##; s#\.git$##'
}

install_approved() {
  local p="$1" r before after out n f blob
  r="$(basename "$p")"
  before="$(git -C "$p" rev-parse HEAD)"
  n="$(git -C "$p" rev-list --count HEAD..origin/main)"
  [[ "$n" -eq 0 ]] && { log "$r: up to date"; return 0; }
  [[ "$DRY" == "1" ]] && { log "$r: ${DRY_TAG}would install $n approved commit(s)"; return 0; }
  # A new file this Mac proposed is still untracked here once its PR merges. If the approved
  # copy is byte-for-byte the same, drop the local one so the install can lay it down.
  while IFS= read -r f; do
    blob="$(git -C "$p" rev-parse -q --verify "origin/main:$f" 2>/dev/null)" || continue
    [[ "$(git -C "$p" hash-object -- "$p/$f")" == "$blob" ]] && rm -f -- "$p/$f"
  done < <(git -C "$p" ls-files --others --exclude-standard)
  if ! out="$(git -C "$p" pull -q --rebase --autostash origin main 2>&1)"; then
    [[ -d "$(git -C "$p" rev-parse --absolute-git-dir)/rebase-merge" ]] && git -C "$p" rebase --abort 2>/dev/null
    alert "$r: could not install approved changes ($(printf '%s' "$out" | tail -n1))"
    return 1
  fi
  if [[ -n "$(git -C "$p" diff --name-only --diff-filter=U)" ]]; then
    # The approved version wins on disk; the local edit is still in the stash.
    git -C "$p" reset -q --hard HEAD
    alert "$r: a local edit collided with an approved change. Approved version installed; your edit is in 'git -C $p stash list'"
  fi
  after="$(git -C "$p" rev-parse HEAD)"
  log "$r: installed approved ${before:0:7}..${after:0:7}"
}

propose_local() {
  local p="$1" r idx tree commit prev base files n rules slug pr body list
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

  commit="$(git -C "$p" commit-tree "$tree" -p HEAD -m "chore(sync): edits from $HOST")"
  base="$(git -C "$p" merge-base origin/main "$commit")"
  files="$(git -C "$p" diff --name-only "$base" "$commit")"
  n="$(printf '%s\n' "$files" | grep -c .)"
  rules="$(printf '%s\n' "$files" | grep -E "$RULES_RE" | tr '\n' ' ' | sed 's/ $//')"

  if ! command -v "$GITLEAKS" >/dev/null 2>&1; then
    alert "$r: gitleaks not installed, edits not proposed (brew install gitleaks)"; return 1
  fi
  "$GITLEAKS" git --no-banner --redact --exit-code 3 --log-opts="origin/main..$commit" "$p" >/dev/null 2>&1
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
if [[ "$DRY" == "1" ]]; then
  log "skills: ${DRY_TAG}would deploy"
elif [[ -f "$WF/deploy-skills.sh" ]]; then
  if DEV_ROOT="$DEV_ROOT" bash "$WF/deploy-skills.sh" >/dev/null 2>&1; then
    log "skills: deployed"
  else
    alert "skills: deploy failed (run bash $WF/deploy-skills.sh to see why)"
  fi
fi

# ── notify ────────────────────────────────────────────────────────────────
if [[ -n "$ALERTS" && "$NO_NOTIFY" != "1" ]]; then
  # Quotes and backslashes would break the AppleScript string.
  # shellcheck disable=SC1003
  msg="$(printf '%s' "$ALERTS" | tr '"\\' "' " | cut -c1-400)"
  osascript -e "display notification \"$msg\" with title \"Skill sync\"" >/dev/null 2>&1 || true
fi
exit 0
