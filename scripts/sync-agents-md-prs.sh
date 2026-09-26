#!/usr/bin/env bash
set -uo pipefail
WF=$HOME/Developer/dev-workflow/AGENTS.workflow.md
WT=$1; BR=chore/sync-agents-md-design-brief
cd $HOME/Developer
for d in */; do r=${d%/}; [[ $r == dev-workflow ]] && continue
  [[ -d $r/.git && -f $r/AGENTS.md ]] || continue
  git -C $r remote get-url origin >/dev/null 2>&1 || { echo "$r: no remote"; continue; }
  git -C $r fetch -q origin 2>/dev/null
  def=$(git -C $r symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#origin/##'); def=${def:-main}
  git -C $r show origin/$def:AGENTS.md 2>/dev/null | grep -c "BEGIN CANONICAL WORKFLOW" >/dev/null || { echo "$r: no marker on origin/$def"; continue; }
  p=$WT/$r; git -C $r worktree add -q -b $BR $p origin/$def 2>/dev/null || { echo "$r: worktree failed"; continue; }
  awk -v blockfile="$WF" 'BEGIN { while ((getline line < blockfile) > 0) blk = blk line "\n" }
    index($0, "<!-- BEGIN CANONICAL WORKFLOW") { inblock=1; printf "%s", blk; next }
    index($0, "<!-- END CANONICAL WORKFLOW -->") { inblock=0; next }
    !inblock { print }' $p/AGENTS.md > $p/AGENTS.md.tmp && mv $p/AGENTS.md.tmp $p/AGENTS.md
  if git -C $p diff --quiet; then echo "$r: already current"
  else
    git -C $p commit -q -am "chore: re-sync canonical workflow block (design brief handoff) [MCR-1796]

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" && git -C $p push -q -u origin $BR 2>/dev/null
    url=$(cd $p && gh pr create -B $def --title "chore: re-sync canonical workflow block (design brief handoff) [MCR-1796]" --body "Re-syncs the canonical AGENTS.md block from zmcray/dev-workflow#6: planning that stops at \"design first\" now writes a design brief and waits for the canvas link.

🤖 Generated with [Claude Code](https://claude.com/claude-code)" 2>&1 | tail -1)
    echo "$r: PR open $url"
  fi
  git -C $r worktree remove --force $p; git -C $r branch -D $BR -q 2>/dev/null || true
done
