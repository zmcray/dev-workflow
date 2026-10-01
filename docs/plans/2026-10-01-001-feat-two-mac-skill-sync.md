---
Created: 2026-10-01
Flow: standard
Linear Project: Workflow
Linear Issue: MCR-2353
Linear Branch: zack/mcr-2353-keep-skills-identical-on-both-macs-and-stop-factory-running
Task: Keep both Macs on the same approved skills and workflow rules: local edits become a pull request automatically, only merged changes install, and /factory never runs a stale or unapproved copy from the other Mac.
---

# Two-Mac skill sync, review-gated

## Problem

Zack writes and runs skills on two Macs (MacBook, iMac). On 2026-09-30 the iMac's Motus factory run used a day-old `/factory`: MCR-2125 merged at 20:02 and the iMac's only sync runs at 17:00. Today's sync (`scripts/sync-skills.sh`, launch agent `com.mcray.skill-sync`):

- runs once a day at 17:00, and nothing checks again before the night shift;
- deploys a hard-coded list (`factory packets caspian` + `wizard`); `ss`, `zmcray-kickoff`, `code-review`, `domain-modeling`, `grilling` and the Codex skills are copied by hand, if at all;
- never captures an edit made on one Mac: a skill edited in `~/.claude/...`, or written straight into `~/.claude/skills` (`progress-dashboard`), or an uncommitted repo edit (the MacBook's software-factory `AGENTS.md`, `SORT.md`), stays on that Mac;
- skips a repo with any local change and only logs it, so one stray edit stops all updates on that Mac silently.

## Decision (Zack, 2026-10-01)

Review-gated, the pattern teams use for one shared skill set (research below). Rejected: an hourly job that auto-pushes every edit to the other Mac. A bad change to `AGENTS.md` or a skill would spread within an hour with no review, and the overnight agent obeys it.

The two repos govern how both Macs and the coding workflow behave, so **everything in them** is in scope, not only skill files.

## Requirements

- R1. **Propose, never publish.** Once a day (and on demand), each Mac turns its unmerged local changes in `~/Developer/dev-workflow` and `~/Developer/software-factory` into a pull request on a per-Mac branch `sync/<host>`. The job never merges and never pushes to `main`. Merging the PR is the approval.
- R2. **Install only what is approved.** Each Mac fast-forwards to `origin/main` (merged changes only) and re-installs. Another Mac's unmerged edits never reach this Mac.
- R3. **Capture edits wherever they were made.** Changes in the repo checkouts; edits made to an installed copy (`~/.claude/commands/<name>.md`, `~/.claude/skills/<name>/`) are copied back into the repo first; a skill written straight into `~/.claude/skills/<name>/` (not gstack-managed, not on the ignore list) is adopted into `software-factory/skills/<name>/` (private repo).
- R4. **Deploy everything.** Every `commands/*.md` (both repos), every `software-factory/skills/*/`, every `dev-workflow/codex/skills/*/`, and the helper scripts. No hard-coded lists.
- R5. **No secrets in a proposal.** `gitleaks` scans each proposal before it is pushed (dev-workflow is a **public** repo). A hit pushes nothing and notifies. No `gitleaks` → no proposal (fail closed).
- R6. **Never block, never lose.** Local edits never stop the install (`--autostash`). If an approved change collides with a local edit, the approved version wins on disk and the local edit is kept in a named stash, with a notification.
- R7. **Say it out loud.** One macOS notification per run when something needs Zack: a new or updated proposal (files listed; `AGENTS.md`, `AGENTS.workflow.md`, `SORT.md`, `DISPATCH.md` and `commands/factory.md` flagged as rule changes), a secret hit, a collision, a failure.
- R8. **`/factory` starts on the approved version.** Step 0 of `/factory` fetches; if `main` moved, it installs the approved version, then re-reads its own command file from disk and follows that. It never installs unmerged edits. If the Mac has its own unmerged edits, the run notes it in the ledger and continues.

## Units

### U1. `deploy-skills.sh`: deploy everything, from discovery
- Commands: every `dev-workflow/commands/*.md` and `software-factory/commands/*.md` → copy to `~/.claude/commands/<name>.md`; render (minus `argument-hint:`) to `~/.cursor/skills/<name>/SKILL.md`, and to `~/.agents/skills/<name>/SKILL.md` unless a native Codex version exists in `dev-workflow/codex/skills/<name>/`.
- Codex-native skills: `dev-workflow/codex/skills/<name>/` → `~/.codex/skills/<name>/`. A stale Codex fork is archived only when no native version exists.
- Folder skills: every `software-factory/skills/<name>/` → `~/.claude/skills/`, `~/.agents/skills/`, `~/.cursor/skills/`.
- Helpers as today. Copies only, never deletes. `--dry-run` kept. `HOME` and `DEV_ROOT` honoured so it can be tested against a sandbox.
- Files: `deploy-skills.sh`.

### U2. `sync-skills.sh`: capture, propose, install
1. Lock (`mkdir` lock dir); a second run exits.
2. Capture (R3): installed copies newer than and different from their source are copied back; unmanaged skill folders are adopted. Ignore list: `scripts/skill-sync.ignore` (seed `proof`).
3. Per repo, only the main checkout, only on `main`, not mid-merge or mid-rebase (else notify and skip):
   - `git fetch`.
   - **Propose:** if the working tree or local commits differ from `origin/main`, build a commit of the working tree in a temporary index (the working tree and local `main` are untouched), parent = local `HEAD`; gitleaks scans that commit; push it to `sync/<host>` (force-with-lease, the branch is the Mac's own); open a PR if none is open; notify with the file list. Unchanged since the last proposal → no push, no notification.
   - **Install:** `git pull --rebase --autostash` to `origin/main`. On a stash collision: keep the stash under a named message, restore the tree to `origin/main`, notify.
4. Run `deploy-skills.sh` when anything changed on disk or any installed copy differs from its source.
- Test hooks: `SKILL_SYNC_DRY=1` (no push, no PR), `SKILL_SYNC_NO_NOTIFY=1`, `GH` and `GITLEAKS` overridable.
- Files: `scripts/sync-skills.sh`, `scripts/skill-sync.ignore` (new).

### U3. Launch agent and setup
- `install-skill-sync.sh`: daily at 17:00 as today (catches up at wake), plus `RunAtLoad`. `setup-factory-machine.sh`: no longer refuses a dirty repo (the sync proposes it), wording updated. README deploy sections point at the one script.
- Files: `scripts/install-skill-sync.sh`, `scripts/setup-factory-machine.sh`, `README.md`.

### U4. `/factory` Step 0 (R8)
- New first preflight step: fetch both repos; if either main checkout is behind `origin/main`, run `bash ~/Developer/dev-workflow/scripts/sync-skills.sh`, then re-read the deployed factory command from disk and follow it from Step 1. Unmerged local edits → one ledger note, continue.
- Files: `commands/factory.md`.

## Research decision

- Decision: extend (web research, 2026-10-01, summarised here; dev-workflow has no research corpus).
- Evidence: Claude Code plugin marketplaces ship with auto-update off for third-party sources, pin by ref or version, and keep old versions for rollback (code.claude.com/docs/en/plugins/install, /plugins/host-marketplace, /plugins/loading). Anthropic's team skills-repo guidance routes every change through code review before it syncs (claude.com/docs/claude-tag/admins/skills-repo). chezmoi's daily flow is pull, diff, then apply, with auto-push opt-in (chezmoi.io user guide). AGENTS.md is an injection target and is treated like executable config (NVIDIA and Backslash write-ups).
- Additional research: none. Moving skills into a pinned private plugin was considered and deferred: bigger migration, and plugin support for shipping `AGENTS.md` is unconfirmed.

## Self-review

- **Feasibility:** `/bin/bash` 3.2 runs the agent: no associative arrays, no `mapfile`. `gitleaks` 8.30 scans a commit range with `gitleaks git --log-opts=<range>`. Temporary-index commits (`GIT_INDEX_FILE`, `git add -A`, `write-tree`, `commit-tree`) leave the working tree and `main` untouched.
- **Scope:** plugin updates (gstack, compound-engineering) and Keychain secrets stay out; secrets remain one wizard run per Mac.
- **Security:** nothing reaches `main` or the other Mac without a merge. Proposals to the public repo are secret-scanned and fail closed. The job never auto-merges and never pushes to `main`.
- **Reversibility:** revert the merge; both Macs follow on the next install. Copies only, collisions kept in a named stash, `launchctl bootout` stops the job.

## Landing

One group PR in dev-workflow, one commit per unit, `[MCR-2353]` in each subject. Then Zack runs `bash ~/Developer/dev-workflow/scripts/setup-factory-machine.sh` once on each Mac.
