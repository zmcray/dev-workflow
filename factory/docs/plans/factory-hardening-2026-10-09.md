# Factory hardening: proof before merge, slim instructions, one source

- **Created:** 2026-10-09
- **Tier:** not set (each unit is sized below; tier at /packets time)
- **Linear Project:** Workflow
- **Linear Issues:** MCR-2719 (Unit 1), MCR-2720 (Unit 2), MCR-2721 (Unit 3), MCR-2722 (Unit 4)
- **Task:** Fix the gaps the 2026-10-09 Claude Code setup review found in the build system: CI and agents don't prove work before merge, the shared AGENTS.md block is too large to be followed reliably, the rules live in two repos that disagree, and worktrees/branches pile up.

## Why now

- About 500 PRs merged in 3 weeks across pulse, motus, telos and sonar, about 97% Claude co-authored. The factory produced 229 of them across 47 runs.
- That volume is only safe if the gates are real. Today they are partly not:
  - Motus PR CI skips the full UI suite. Main went red 09-21 and 10-01, which caused 3 factory hard stops.
  - Ledgers record 0 `failed` out of 229 chunks.
  - 106 post-merge checklist items are left for a human to clear.

Order: Unit 1 first (safety), then Unit 3 (it decides where Unit 2's text lives), then Unit 2, then Unit 4.

## Unit 1: Proof before merge (MCR-2719)

**Goal:** an agent can't end a turn on red, and a PR can't merge on a suite it didn't run.

- **Motus CI:** `.github/workflows/ci.yml` gates the UI suite on `github.event_name != 'pull_request'` (lines 322, 362).
  - Run the UI suite on PRs.
  - If wall time is the reason it was skipped, run a tagged smoke subset on every PR plus the full suite on PRs that touch app code (`steps.tier.outputs.run_app`).
- **Stop hook per repo:** commit `.claude/settings.json` in pulse, motus, telos and sonar.
  - It holds a `Stop` hook that runs the repo's fast check (typecheck + unit tests, under ~90s).
  - It exits with a blocking code on failure, so Claude keeps working instead of ending the turn.
  - Ship the hook script from dev-workflow next to the AGENTS block, so there is one copy.
- **Honest ledgers:**
  - Factory writes `failed` when a chunk's gate fails after its retry budget.
  - The morning report shows `done / failed / parked` counts on its first line.
- **Verify:**
  - Open a throwaway PR in motus that breaks one UI test and confirm merge is blocked.
  - In a session, break a unit test and confirm the Stop hook blocks the turn end.

## Unit 2: Slim the canonical block (MCR-2720)

**Goal:** about 60 lines of hard rules that load every session. Everything procedural loads on demand.

- **Keep in the core:**
  - The never-do list (prod DB, direct pushes, secrets).
  - The merge rule.
  - Where plans, ledgers and PRDs live.
  - The Linear basics (team, which labels mean spec-ready).
  - One pointer line per procedure.
- **Move out** to the skill or command that already owns each topic:
  - Review depth goes to factory and lfg.
  - Packet rules go to /packets.
  - Wizard PR rules go to wizard.
  - Linear writing style goes to a small `linear-style` reference loaded by the skills that write issues.
- **Mechanics:**
  - No line over 300 characters.
  - `deploy-agents-md.sh` still ships one identical block (md5 check stays).
- **Verify:**
  - Run one factory shift on pulse with the slim block.
  - Compare rule violations in its ledger and PRs against the last 3 pulse runs.

## Unit 3: One source, conflicts settled (MCR-2721)

Pick one home. **Recommendation:** dev-workflow stays the source, because it is what deploys today. software-factory's MANUAL, DISPATCH, SORT and templates move in under `factory/`, and software-factory is archived with a pointer README.

Conflicts to settle, one written answer each:

1. **Auto-merge.**
   - Today: the block auto-merges everything on green, while the software-factory README says auto-merge is earned per task class.
   - Proposal: auto-merge on green for `flow:ship` and `flow:standard`; `flow:design` and anything touching migrations opens a draft for morning review.
2. **Stuck issue.**
   - Today: AGENTS says stop the run; factory.md says mark it failed and move on.
   - Proposal: mark it failed and move on, unless the failure is a red baseline on main. Then stop.
3. **`night-eligible`.**
   - Today: /packets says a human applies it; the factory never checks it.
   - Proposal: either factory filters on it, or the label is deleted from /packets. Don't keep a gate that does nothing.
4. **Plan filenames.**
   - Today: ce-plan writes the date first, which breaks the global date-last rule.
   - Proposal: add an override note to the block, or rename on write in /packets.
5. **Stale copy.** Close or finish software-factory PR #18 as part of the move.

## Unit 4: Worktree and branch hygiene (MCR-2722)

- **Today:** 71 extra worktrees (telos 30, motus 18, pulse 16, sonar 4), about 25 with unmerged work. telos has 328 local branches, 105 with a deleted upstream.
- **Change `worktree-sweep.sh`:**
  - Remove a worktree only when its branch is merged into the default branch AND the tree is clean.
  - Delete a local branch only when its upstream is gone AND it is merged.
  - Everything else is reported, never touched.
- **sim-reaper:** install it as a launch agent or remove it from the README. The telos disk-full stop on 09-30 is the cost of it being missing.
- **Verify:** dry-run output reviewed once by Zack before the first live run.
