# dev-workflow

Canonical home for the cross-tool product build workflow. Keeps how-an-issue-gets-built consistent across coding tools (Claude Code, Codex, Cursor, Copilot, Gemini CLI). The workflow logic lives here once and deploys to every repo, so switching tools changes nothing.

Lives at `~/Developer/dev-workflow` (private GitHub repo). Dev infrastructure sits with the code, version-controlled, edited in CC.

## Layout

```
AGENTS.workflow.md     canonical, tool-agnostic workflow block (single source of truth)
deploy-agents-md.sh    pushes the block into each repo + repoints CLAUDE.md
README.md              this file
commands/              the zmcray:* Claude Code skill sources (build, wrap, kickoff,
                       status, checkpoint, retro, ss)
```

## How it works

Each repo gets an `AGENTS.md` = repo-specific context header + the canonical workflow block (between `<!-- BEGIN/END CANONICAL WORKFLOW -->` markers). `CLAUDE.md` becomes a one-line `@AGENTS.md` import, so Claude Code reads the same source Codex and Cursor read directly.

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

1. Edit `AGENTS.workflow.md` (workflow) or a file in `commands/` (a skill).
2. Re-run the relevant deploy command above.
3. Commit. The repo's git history is the version record.

## Repos covered

The deploy script acts on any repo in `~/Developer` from its list (the 4 migrated: first-tack, helm, cgsc, atlas-os; plus 10 pending migration, picked up automatically once moved).

Created 2026-06-13. Moved from `Work/40_OS/01_Workflows/agents-md/` to its own repo the same day.
