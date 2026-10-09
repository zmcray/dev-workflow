<!-- BEGIN CANONICAL WORKFLOW (managed by deploy-agents-md.sh ... edit here, not in repos) -->

## Workflow core

Hard rules for every session in every harness. Procedures live in `~/Developer/dev-workflow/rules/`; open the one a task needs before starting that task. They bind as fully as this block.

### Never

- Never ask Zack to paste a secret into chat, a file, or a command line, and never print, log, or echo a secret value. Hand him one command that prompts silently, writes every destination, and unsets the variable; verify by name only (`gh secret list`, `grep -c '^NAME=' .env`):

  ```bash
  read -rs "KEY?Paste NAME: " && echo && printf '\nNAME=%s\n' "$KEY" >> <repo>/.env && printf '%s' "$KEY" | gh secret set NAME -R <owner/repo> && unset KEY && echo "Done"
  ```

- Never work on `main`. Check out the default branch and pull it before branching; use the Linear `gitBranchName`, else `feat/<short-slug>`.
- Never merge a red or blocked PR, and never merge part of a group PR.
- Never weaken, skip, or mock a failing assertion to get CI green. Quarantine a flaky test with a Linear issue instead.
- Never assume a code deploy applies DB migrations. Confirm each new migration reaches the prod DB; destructive or renaming ones go first.
- Never write a model name in an issue, plan, or packet.
- Never name an issue ID anywhere in a plan, brief, ledger, wizard, or other docs PR (branch, title, commits, body). Comment its URL on the issues instead.
- Never put `Part of`, `ref`, `related to`, `towards`, `updates`, or `contributes to` before an issue ID in any PR.
- Never expand scope past the PRD on a `prd-source` issue: comment "Scope exceeds PRD: [reason]. Kicking back for Caspian EXPAND.", move it to Backlog, stop.
- Never de-escalate a flow label mid-build. Escalate up when the blast radius grows, and say why in Linear.

### Merge and commit

- **Merge on green.** CI green → merge (squash one chunk, `gh pr merge --rebase --delete-branch` for a group), pull the default branch, comment "PR merged" on each chunk's issue.
- Runs are strictly sequential: merge group N before branching N+1. If a PR cannot merge, stop the run there. Opt out per repo with `"automerge": false` in `.linear-project.json`.
- PR review is not a gate. CI plus checking the live app after merge are.
- Commits are conventional with the issue ID: `feat: implement upload flow [MCR-123]`. One commit per chunk; leave the tree clean before the next chunk.
- Test-first on `flow:design` and `flow:standard`: the failing test comes before the code.
- **Escalation list:** auth, sessions, tokens, RLS or grants, migrations, deletion or export, payments, outbound fetch. A diff touching one gets the full `flow:design` review and lands in its own PR.

### Linear basics

- Linear, Mcraygroup team, is the audit trail: move status as work moves, comment plan and review summaries, link the PR. Every residual or follow-up is filed there.
- No issue is created without all four: **project, milestone, priority (never "No priority"), one `flow:*` label.** Residuals go to the `<Epic>: hardening` milestone.
- `flow:design` = new surface, architecture, auth/data/payments, hard to reverse. `flow:standard` = meaty feature in known territory. `flow:ship` = small, reversible, well-specced.
- `prd-source` = strategy already ran, skip Think. `spec-ready` = buildable. `gate:human` and `ops` = day shift only, never overnight. Also `tier:*`, `design:*`, `deferred`.

### Where things live

- Plans: `docs/plans/<short-description>-YYYY-MM-DD.md`, date last (taken name: counter before the date). Archive to `docs/plans/archive/` with an `## Outcome` note.
- PRDs `docs/strategy/` · factory ledgers `docs/factory/runs/` · checkpoints `docs/checkpoints/` · design briefs `docs/design/briefs/` · wizards `scripts/wizards/`
- Research `docs/research/` (start at `INDEX.md`) · one glossary, `CONCEPTS.md` · ADRs `docs/adr/` · Linear link `.linear-project.json`

### Read before (files in `~/Developer/dev-workflow/rules/`)

- Any multi-step task: state a one-line delegation call first, default delegate-and-downshift → `delegation.md`
- Working an issue (phases, flow routing, review depth, effort, plan header, session close) → `build.md`
- Creating or editing Linear issues or milestones, the hygiene check, the session-close status update → `linear.md`
- A plan with 3+ Implementation Units: cut it into chunks (`/packets`) before building or ending the session. Chunk size, `tier:*`, `gate:human`, wizards, group PRs → `chunks.md`
- Planning an issue with no `design:*` label, or a `design:screens` / `journey` / `product` issue → `design.md`
- A `/goal` or `/factory` run → `goal-runs.md`
- Touching `.github/workflows/**` → `ci.md`
- Wiring a new repo, iOS keys, a deployed DB's migration path, shadcn registries → `setup.md`
- Any Think or Plan phase resting on user, market, or behavior claims → `research.md`

<!-- END CANONICAL WORKFLOW -->
