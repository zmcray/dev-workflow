---
name: progress-dashboard
description: Build a one-page progress dashboard for a Linear-tracked repo and publish it as an Artifact... for the whole project, one epic (milestones sharing a prefix like "Circuits"), or one milestone. Shows phases, the critical chain, what is blocked, and what closed each day, in plain words. Use for "/progress-dashboard", "dashboard for <epic>", "where are we with <epic>, make me a dashboard", "project dashboard", "status board", "show progress on <milestone>". Do NOT trigger for code-quality scores (use health), a PR landing queue (use landing-report), a weekly retrospective (use retro), charts from query results or metrics (use data:build-dashboard), or the Linear project status update at session close (AGENTS.md owns that).
argument-hint: "[project | <epic name> | <milestone name>]"
---

# Progress dashboard

## Context

- **Repo wiring.** The repo root holds `.linear-project.json` (project `id`, `slug`, `name`, `team`). Milestones follow the AGENTS.md naming: `<Epic> N: <Outcome>` for live phases, plus `<Epic>: hardening` and `<Epic>: later` shelves. Every live milestone description starts with `Outcome:` and `Order:` lines. Older milestones with no `<Epic>:` prefix count as "Shipped earlier".
- **Epic.** The shared prefix of a group of milestones ("Circuits" covers `Circuits 1`, `Circuits 2`, `Circuits: hardening`, `Circuits: later`).
- **Critical chain.** The longest open `blocked by` path through the scope's live milestones. Source it in this order: the `## Chunks` table of the plan named on a milestone's `Contract:` or `UI:` line (`docs/plans/`), then the milestone `Order:` line.
- **Files in this folder.**
  - `summarize.py`: counts issues from a Linear `list_issues` dump. Run `python3 summarize.py --help`.
  - `template.html`: the page. Every section carries a comment saying which mode uses it and how to fill it.
  - `example-epic.html`: a finished epic dashboard. Match its tone, density and copy style.
- **Repo signals.** `docs/checkpoints/` (handoffs naming unfixed findings), `docs/factory/runs/*.json` (the latest night-shift ledger: `skipped` reasons and item notes), `DESIGN.md` (palette tokens, when present).
- **Surface.** IF the `Artifact` tool is present, publish there. ELSE (Codex, Cursor) write the page to `docs/dashboards/<slug>.html` and open it with `open`.
- **Tiers.** Follow AGENTS.md Delegation: bulk reads and log reduction go to the cheapest tier; the verdict, the alert calls and the copy stay in the main thread.

## Behaviour

1. **Pick the scope.** Read the argument. `project` or nothing with no epic in the request → project mode. A name matching an epic prefix → epic mode. A name matching one milestone (it has a number or a shelf suffix) → milestone mode. IF the name matches nothing, list the epic prefixes from step 2 and ask which one. Never guess between two matches.
2. **Pull Linear.** Read `.linear-project.json`. Call `list_milestones` for the project. Call `list_issues` for the project with `limit: 250` and `fields: ["id","title","status","statusType","projectMilestone","labels","priority","completedAt","startedAt","updatedAt"]`, following `cursor` until the last page. Save every page to a scratch file: an oversized result is already saved to a file by the tool; write an inline result to a file yourself.
3. **Find cross-milestone links (epic and milestone modes).** Read the scope's milestone descriptions. Any issue ID named in an `Order:` line that lives in another milestone and gates this scope goes in `--extra`.
4. **Count.** Run `summarize.py <pages…> --scope <mode> --name "<name>" --extra <ids> --today <YYYY-MM-DD>`. Use its numbers verbatim. Never recount by hand.
5. **Read the repo signals.** In parallel:
   - `gh run list --branch <default> --limit 5 --json conclusion,displayTitle,workflowName,createdAt` (is the default branch red?)
   - `gh pr list --state open --json number,title,headRefName,isDraft,statusCheckRollup`
   - For each in-progress issue from step 4: find branches whose name contains its ID (`git branch -a`, `git ls-remote --heads origin`). For a local-only branch, record commits ahead of the default branch, lines changed (`git diff --stat`) and last commit date.
   - The newest file in `docs/checkpoints/` and the newest `docs/factory/runs/*.json`, only when either names an issue in scope.
6. **Build the critical chain (epic and milestone modes).** Take the chain from the source named in Context. Mark each node done, in progress, stuck, not started, or needs a human (`gate:human`). Label nodes with the plan's unit code when there is one (`U6`, `C12`), else a short number. Title each node in 2 to 4 plain words.
7. **Decide the alerts.** Check these, in this order, and keep at most 5:
   - Default branch CI red → Blocking.
   - In-progress issue with work on a local-only branch, or no branch and no PR, untouched for 24 hours or more, while other scope issues are blocked by it → Blocking. Say how many issues wait on it.
   - Open PR in scope with failing checks → Blocking.
   - An issue a checkpoint or ledger says has unfixed review findings or a hard stop → Stuck.
   - In-progress issue with no branch and no PR, untouched for 48 hours or more, that blocks nothing → Stuck, pill `Idle`. The night shift skips started issues, so name them together in one alert.
   - Open `gate:human` issue: its blockers are done → Needs you, pill `Now`. Otherwise pill `Later`.
   - Any issue on `design:screens`, `design:journey` or `design:product` without a canvas link → Stuck, pill `No canvas`.
   IF none apply, the section is one `.clear` line naming the next step.
8. **Write the verdict.** One sentence in `<b>`, bad news first if there is any, then one short sentence of consequence. Plain words: "the player screen is half built", not "Circuits 2 is at 50%".
9. **Fill the page.** Copy `template.html` to the scratch directory and fill it. Remove the sections the mode does not use (per the template comments) and every template comment. Replace the example rows. Keep the component classes; do not add new visual styles. IF the repo has `DESIGN.md` with color tokens, swap the `:root` values for them (both themes). Title: `<Project> Build Tracker` (project mode), `<Epic> Build Tracker` (epic), `<Milestone short name> Tracker` (milestone, e.g. "Circuits 2 Tracker").
10. **Publish.** Call `Artifact` with `action: "list"` and look for an artifact with the same title. IF one exists, `read` it, then publish the new file with its `url` so the link stays the same. ELSE publish a new one with `icon: "chart"` and a one-sentence `description` naming the scope and date.

## Output

The Artifact link, then an exec-brief summary in the chat:

- Line one: the verdict from step 8.
- **What I found:** 4 to 6 bullets, bold number first (phases, chain position, closures in the window, reshapes such as parked or moved milestones).
- **Why it's stuck:** one bullet per Blocking or Stuck alert. Leave the heading out when there are none.
- Close with **Decision needed**, **Action needed**, or **Nothing needed from you**, per the exec-brief rules.
- Last line: "Snapshot as of <date>; it doesn't update itself. Rerun `/progress-dashboard <scope>` to refresh the same link."

## Gotchas

See gotchas.md.
