# dev-workflow

Canonical home for the cross-tool product build workflow. Keeps how-an-issue-gets-built consistent across coding tools (Claude Code, Codex, Cursor, Copilot, Gemini CLI). The workflow logic lives here once and deploys to every repo, so switching tools changes nothing.

Lives at `~/Developer/dev-workflow` (private GitHub repo). Dev infrastructure sits with the code, version-controlled, edited in CC.

## Layout

```
AGENTS.workflow.md          canonical, tool-agnostic workflow block (single source of truth)
deploy-agents-md.sh         pushes the block into each repo + repoints CLAUDE.md
templates/
  AGENTS.md.template        AGENTS.md scaffold: {{REPO}} header + {{CANONICAL_WORKFLOW}} marker
  CLAUDE.md.template        the CLAUDE.md @AGENTS.md import file
README.md                   this file
commands/                   Claude Code command sources. factory, packets, and caspian are
                            portable: deploy-skills.sh also ships them to Codex and Cursor
codex/skills/               Codex-only skill sources (zmcray-kickoff), each a <name>/SKILL.md +
                            agents/openai.yaml, deployed to ~/.codex/skills/
deploy-skills.sh            ships the portable skills to all three harnesses
```

## How it works

Each repo gets an `AGENTS.md` = repo-specific context header + the canonical workflow block (between `<!-- BEGIN/END CANONICAL WORKFLOW -->` markers). `CLAUDE.md` becomes a one-line `@AGENTS.md` import, so Claude Code reads the same source Codex and Cursor read directly.

The deploy script builds these from `templates/`. A fresh repo's `AGENTS.md` is rendered from `templates/AGENTS.md.template` (the `{{REPO}}` header placeholder is filled in and the `{{CANONICAL_WORKFLOW}}` marker is replaced with the contents of `AGENTS.workflow.md`, so the block stays single-sourced). `CLAUDE.md` is copied from `templates/CLAUDE.md.template`. A repo that already has context in its `CLAUDE.md` keeps that as the header instead of the scaffold. Re-runs only re-sync the marked block.

The block defines the two routing signals (`flow:*` rigor + `prd-source` strategy-done), the flow table, the four phases (Think / Plan / Execute / Learn) as roles with command implementations (gstack, Compound Engineering) and native fallbacks, the four orthogonal axes (flow / effort / delegation / autonomy), plus commit / test-first / residual / kick-back / escalation discipline, and the one-time Project setup convention.

The **Delegation** axis is a hard rule, not a hint: every step with more than a couple of tool calls must have a stated tier call, the default is delegate-and-downshift, and all GitHub/CI work that loops or returns bulk output (CI watch, Actions log reduction, PR body assembly, workflow YAML) runs on the cheapest tier that can do it. Judgment — flow triage, plan approval, architecture, failure diagnosis, the merge call — stays in the main thread. The `zmcray-*` command files name Claude Code's models directly (`haiku` / `sonnet` / `opus`); plans and Linear issues never do, since other harnesses read those.

The canonical block also defines **CI cost discipline**. It preserves test coverage while reducing wasted Actions usage through cancellation of superseded runs, a change-classification gate (docs-only changes skip app CI; one always-running required check decides pass/fail, and unknown paths run full CI), fast PR gates plus full merge/manual suites, fewer tiny billed jobs, short failure-only artifact retention, scheduled-job preflights, and local verification before batched pushes. Planning records a `## CI Impact` contract when a change affects CI; build and execute enforce it.

## Deploy the workflow (AGENTS.md)

```bash
bash ~/Developer/dev-workflow/deploy-agents-md.sh --dry-run   # preview
bash ~/Developer/dev-workflow/deploy-agents-md.sh             # apply
```

Idempotent and non-destructive: re-running re-syncs the block, backs up any replaced `CLAUDE.md` to `CLAUDE.md.pre-agents.bak`, never deletes, and skips repos not yet in `~/Developer`. A timestamped log is written next to the script.

The script also runs a **skill drift check** first: it compares every `commands/*.md` and `codex/skills/*/SKILL.md` source against its deployed copy (`~/.claude/commands/`, `~/.codex/skills/`) and warns with the direction — a deployed copy newer than source means someone edited the live file and it must be synced back before touching source; a newer source means the deploy cp below hasn't run. Warn-only; it never copies skills itself.

## Deploy the skills

Every skill in this repo and in `software-factory` ships by discovery, no hand lists:

```bash
bash ~/Developer/dev-workflow/deploy-skills.sh --dry-run   # preview
bash ~/Developer/dev-workflow/deploy-skills.sh             # apply
```

- `commands/<name>.md` (here or in `software-factory/commands/`) → `~/.claude/commands/` (Claude Code), rendered without Claude-only frontmatter to `~/.cursor/skills/<name>/SKILL.md` (Cursor) and `~/.agents/skills/<name>/SKILL.md` (Codex, unless a native Codex version exists).
- `codex/skills/<name>/` → `~/.codex/skills/<name>/` (Codex-native skills, a different format).
- `software-factory/skills/<name>/` → `~/.claude/skills/`, `~/.agents/skills/`, `~/.cursor/skills/`.
- A stale fork in `~/.codex/skills/<name>` of a skill with no native Codex version is moved to `~/.codex/skills-archive/` so Codex never loads two. Copies and moves only, never deletes.

Each harness still needs its own Linear connection and an unattended permission setup before it can run `/factory`; the skill's preflight step hard-stops without them. See "Running on each harness" in `commands/factory.md`.

## Keeping both Macs the same (review-gated sync)

`scripts/sync-skills.sh` runs daily at 17:00 and at login (launch agent `com.mcray.skill-sync`, installed by `scripts/install-skill-sync.sh`), and `/factory` runs it before every shift. For both repos' main checkouts:

1. **Capture.** An edit made to an installed copy is copied back into its repo. A skill written straight into `~/.claude/skills/<name>/` is adopted into `software-factory/skills/` (gstack skills and `scripts/skill-sync.ignore` excepted).
2. **Install approved.** Fast-forward to `origin/main`: merged changes only. Another Mac's unmerged edits never arrive.
3. **Propose local.** Any local change left becomes one commit on this Mac's `sync/<host>` branch, secret-scanned with `gitleaks` (fail closed; this repo is public), pushed, and opened as a pull request. **Merging it is the approval.** The job never merges and never pushes to `main`.
4. **Deploy** everything above.

You get one macOS notification when something needs you: a proposal to review (rule files such as `AGENTS.md`, `SORT.md` and `commands/factory.md` named), a secret hit, a collision (the approved version wins on disk; your edit stays in `git stash list`), or a failure. Preview without writing anything: `SKILL_SYNC_DRY=1 bash scripts/sync-skills.sh`. Log: `~/Library/Logs/skill-sync.log`. Stop it: `launchctl bootout gui/$(id -u)/com.mcray.skill-sync`.

## Disk upkeep

Factory nights and CI create iOS simulators faster than a weekly sweep clears them (MCR-2346: 146 GB in three days). `scripts/sim-reaper.sh` runs at 00:00, 06:00, 12:00 and 18:00 (launch agent `com.mcray.sim-reaper`, installed by `scripts/install-sim-reaper.sh`). It deletes any simulator that is shut down and has been idle for 6 hours, or 30 minutes when the data volume has under 40 GB free. It never touches a running simulator. Scripts that reuse a named simulator recreate it when it is gone. Preview: `bash scripts/sim-reaper.sh --dry-run`. Log: `~/Library/Logs/sim-reaper.log`.

`scripts/disk-sweep.sh` clears regenerable caches (app caches, package managers, DerivedData, XcodeBuildMCP output) every Monday at 10:00 (`com.mcray.disk-sweep`, installed by `scripts/install-disk-sweep.sh`). Log: `~/Library/Logs/disk-sweep.log`. `setup-factory-machine.sh` installs both.

## Updating

1. Edit `AGENTS.workflow.md` (the workflow block), a file in `templates/` (the AGENTS.md/CLAUDE.md scaffolds), a file in `commands/` (a Claude Code skill), or a file under `codex/skills/` (a Codex skill), on either Mac.
2. Commit and open a PR yourself, or leave it: the next sync proposes it for you.
3. Merge. Both Macs install it on their next sync, and `/factory` before its next shift.

Note: a skill's *steps* are dual-sourced — `commands/<name>.md` (Claude) and `codex/skills/<name>/SKILL.md` (Codex) are separate files in different formats. When you change what a skill *does*, update both so the tools stay in lockstep. Tool-agnostic build and CI cost rules live once in `AGENTS.workflow.md` and reach every tool via each repo's `AGENTS.md`; only the thin per-tool skill wrappers are duplicated.

## Repos covered

The deploy script auto-discovers every git repo directly under `~/Developer`, so new repos are covered with no edits. It skips: the `dev-workflow` repo itself, anything in the `EXCLUDE` list at the top of the script, and any repo containing a `.agents-skip` file. Drop an empty `.agents-skip` in any repo (e.g. a third-party clone) you do not want the build workflow injected into. Always run `--dry-run` first to see the exact list it will touch.

Created 2026-06-13. Moved from `Work/40_OS/01_Workflows/agents-md/` to its own repo the same day; templates extracted from the deploy script the same day.
