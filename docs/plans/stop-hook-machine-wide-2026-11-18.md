---
Created: 2026-11-18
Flow: standard
Linear Project: Workflow
Linear Issue: MCR-3307
Linear Branch: zack/mcr-3307-u6-finish-mcr-2719-for-real-stop-hook-machine
Task: One Stop hook per Mac that reads each repo's fast check from one table, fails closed, and ships an audit that proves it blocks a red turn.
---

## Research decision

- Decision: none needed
- Evidence: internal tooling; the hook contract is Claude Code's documented Stop and PreToolUse behaviour, and the existing tests pin today's telos check.
- Additional research: none

## Units (test-first, one commit)

1. `config/fast-checks.json`: one table, keyed by GitHub repo name.
2. `hooks/stop-fast-check.sh` reads the table; silent outside it, fails closed inside it.
3. `scripts/guards/swift-swallowed-errors.mjs --worktree`: scans unpushed commits plus staged, unstaged and untracked Swift.
4. `hooks/pretooluse-date-last.sh` also blocks a hand edit to a `.pbxproj` when the repo root has `project.yml`.
5. `scripts/install-claude-hooks.mjs`, called from `setup-factory-machine.sh`: idempotent merge into `~/.claude/settings.json`, backup first.
6. `scripts/hooks-audit.sh`: temp worktree per repo, green must pass, a deliberate break must block.
7. `hooks/README.md`; new tests wired into the CI `tests` job.

## Table design

- Match: the owner and the last path segment of `git remote get-url origin`, case-insensitive. The owner must equal the table's `owner`, so worktrees match and someone else's clone of a same-named repo does not.
- Shape: `budget_seconds` (90) and per repo a list of `{ run, cwd?, when?, files? }`.
- `files: true` appends changed files under `cwd` as `./path`; `"new"` appends only new files (for the date-last guard).
- `{dev_workflow}` in `run` is this checkout; `node` is the Node running the hook.
- Every repo runs the date-last guard first.

## Swift decision

- Measured with `swift test --scratch-path <temp>` so the main checkouts stayed untouched (both folders clean in `git status`).
- motus `MotusKit/`: cold 112 s, warm second run 24 s, warm after a one-line no-op edit (in a temp copy, since the main checkout is never edited) 24 s.
- pulse `ios/PulseKit/`: cold 13 s, warm second run 3 s, warm after a no-op edit 3 s. (Some tests fail in the copy because they scan sibling app folders; the timing still holds.)
- Both under 60 s warm, so both get `swift test` with `when` limited to the package folder.
- saidso has no root package: date-last guard plus the Swift swallowed-errors guard on the worktree.

## Risks

- A fresh worktree's first Swift build is cold (motus about 2 minutes) and will hit the 90 s budget once; the loop guard lets the next stop end. The audit warms the build first.
- Hooks see the PATH Claude Code was started with; a missing `pnpm`, `npx` or `swift` there now blocks (by design), with the fix in the message.
- pnpm 11 runs a dependency check before scripts and may try `pnpm install` when a worktree's `node_modules` is stale.
- telos still has its own Stop entry; remove it after the machine-wide install or the check runs twice.
- Deleted files stay in the `files` list (today's telos behaviour, pinned by the existing test).

## Verification

- `hooks/stop-fast-check.test.sh`: existing contract unchanged (fixture is now a telos remote), plus table cases.
- `scripts/guards/swift-swallowed-errors.test.sh`, `scripts/guards/date-last-names.test.sh`, `scripts/install-claude-hooks.test.sh`.
- `scripts/hooks-audit.sh` run once for real; nothing installed into `~/.claude`.
