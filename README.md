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
commands/                   the zmcray:* Claude Code skill sources (build, wrap, kickoff,
                            status, checkpoint, retro, ss)
```

## How it works

Each repo gets an `AGENTS.md` = repo-specific context header + the canonical workflow block (between `<!-- BEGIN/END CANONICAL WORKFLOW -->` markers). `CLAUDE.md` becomes a one-line `@AGENTS.md` import, so Claude Code reads the same source Codex and Cursor read directly.

The deploy script builds these from `templates/`. A fresh repo's `AGENTS.md` is rendered from `templates/AGENTS.md.template` (the `{{REPO}}` header placeholder is filled in and the `{{CANONICAL_WORKFLOW}}` marker is replaced with the contents of `AGENTS.workflow.md`, so the block stays single-sourced). `CLAUDE.md` is copied from `templates/CLAUDE.md.template`. A repo that already has context in its `CLAUDE.md` keeps that as the header instead of the scaffold. Re-runs only re-sync the marked block.

The block defines the two routing signals (`flow:*` rigor + `prd-source` strategy-done), the flow table, the four phases (Think / Plan / Execute / Learn) as roles with command implementations (gstack, Compound Engineering) and native fallbacks, plus commit / test-first / residual / kick-back / escalation discipline, and the one-time Project setup convention.

## Deploy the workflow (AGENTS.md)

```bash
bash ~/Developer/dev-workflow/deploy-agents-md.sh --dry-run   # preview
bash ~/Developer/dev-workflow/deploy-agents-md.sh             # apply
```

Idempotent and non-destructive: re-running re-syncs the block, backs up any replaced `CLAUDE.md` to `CLAUDE.md.pre-agents.bak`, never deletes, and skips repos not yet in `~/Developer`. A timestamped log is written next to the script.

## Deploy the Claude Code skills

```bash
cp ~/Developer/dev-workflow/commands/*.md ~/.claude/commands/
```

## Updating

1. Edit `AGENTS.workflow.md` (the workflow block), a file in `templates/` (the AGENTS.md/CLAUDE.md scaffolds), or a file in `commands/` (a skill).
2. Re-run the relevant deploy command above.
3. Commit. The repo's git history is the version record.

## Repos covered

The deploy script auto-discovers every git repo directly under `~/Developer`, so new repos are covered with no edits. It skips: the `dev-workflow` repo itself, anything in the `EXCLUDE` list at the top of the script, and any repo containing a `.agents-skip` file. Drop an empty `.agents-skip` in any repo (e.g. a third-party clone) you do not want the build workflow injected into. Always run `--dry-run` first to see the exact list it will touch.

Created 2026-06-13. Moved from `Work/40_OS/01_Workflows/agents-md/` to its own repo the same day; templates extracted from the deploy script the same day.
