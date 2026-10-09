#!/usr/bin/env bash
# worktree-sweep.sh — READ-ONLY report of git worktrees across ~/Developer.
# Deletes nothing, changes nothing (no fetch, no prune, no checkout). Safe to run any time.
# For each extra worktree it reports: unsaved files, whether its work is on the default
# branch, whether anything is still running in it, and a verdict.
#
# Verdicts:
#   SAFE       work is on the default branch, nothing unsaved, nothing running
#   SAVE-FIRST work is on the default branch but uncommitted/untracked files exist
#   LIVE       a dev server, shell, or agent process is running inside it
#   UNMERGED   holds commits whose content is not on the default branch
#   DEAD       registered with git but the folder is gone (bookkeeping only)
set -uo pipefail
DEV="${1:-$HOME/Developer}"
total=0; declare -a rows
for repo in "$DEV"/*/; do
  repo="${repo%/}"; [[ -d "$repo/.git" ]] || continue
  name="$(basename "$repo")"
  def="$(git -C "$repo" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@')"
  [[ -z "$def" ]] && def="main"
  base="origin/$def"; git -C "$repo" rev-parse -q --verify "$base" >/dev/null 2>&1 || base="$def"
  wt=""; br=""
  while IFS= read -r line || [[ -n "$line" ]]; do
    case "$line" in
      "worktree "*) wt="${line#worktree }"; br="(detached)";;
      "branch "*)   br="${line#branch refs/heads/}";;
      "")
        if [[ -n "$wt" && "$wt" != "$repo" ]]; then
          total=$((total+1))
          if [[ ! -d "$wt" ]]; then rows+=("$name|$(basename "$wt")|$br|-|-|DEAD"); wt=""; continue; fi
          unsaved="$(git -C "$wt" status --porcelain 2>/dev/null | grep -v '^?? \.claude/' | wc -l | tr -d ' ')"
          # squash-merge aware: work counts as landed when every file the worktree changed
          # now matches the default branch, or differs only by later commits on that branch.
          mb="$(git -C "$wt" merge-base HEAD "$base" 2>/dev/null)"; unmerged=0
          if [[ -n "$mb" ]]; then
            while IFS= read -r f; do
              [[ -z "$f" ]] && continue
              if ! git -C "$wt" diff --quiet HEAD "$base" -- "$f" 2>/dev/null; then
                only="$(git -C "$wt" diff "$base" HEAD -- "$f" 2>/dev/null | grep -c '^+[^+]')"
                [[ "$only" -gt 0 ]] && unmerged=$((unmerged+1))
              fi
            done < <(git -C "$wt" diff --name-only "$mb" HEAD 2>/dev/null)
          fi
          live="$(lsof +D "$wt" 2>/dev/null | awk 'NR>1 && $1!~/^(com\.appl|mds|mdworker|lsof|fseventsd)/{print $1}' | sort -u | tr '\n' ',' | sed 's/,$//')"
          age="$(( ( $(date +%s) - $(stat -f %m "$wt") ) / 86400 ))d"
          if   [[ -n "$live" ]];        then v="LIVE ($live)"
          elif [[ "$unmerged" -gt 0 ]]; then v="UNMERGED ($unmerged files)"
          elif [[ "$unsaved" -gt 0 ]];  then v="SAVE-FIRST ($unsaved files)"
          else v="SAFE"; fi
          rows+=("$name|$(basename "$wt")|$br|$unsaved|$age|$v")
        fi
        wt="";;
    esac
  done < <(git -C "$repo" worktree list --porcelain 2>/dev/null; echo)
done
echo "WORKTREE SWEEP $(date '+%Y-%m-%d %H:%M') — $total extra worktrees under $DEV (read-only, nothing changed)"
echo "repo|worktree|branch|unsaved|idle|verdict"
printf '%s\n' "${rows[@]:-}" | sort -t'|' -k6,6 -k1,1
