<!-- Moved from the canonical AGENTS.md block (MCR-2720). Read on demand; binding when it applies. -->

# Linear rules

For creating, editing or closing Linear issues and milestones, and for session close.

## Issue tracker

Linear (Mcraygroup team). File all deferred findings, residuals, and follow-ups there. The board is the audit trail: move issue status as work progresses, post plan and review summaries as comments, and link the PR. A reviewer should be able to follow the whole build without opening a terminal.

## Linear structure

Agents create the issues; Zack reads the board. Linear must answer, in under a minute, "what are the sections of work, in what order, and where are we". Structure carries that, never prose.

| Linear object | Means | Zack reads it as |
|---|---|---|
| Initiative | One product. **One per product, ever** | "My product" |
| Project | The repo's project (`.linear-project.json`) | The board |
| Milestone | An ordered phase of an epic, named as a user outcome | "Where we are inside that section" |
| Issue | One chunk: one commit, landed in a group PR | A line item |
| Blocking link | Hard dependency | The order |
| Priority | Rank among unblocked issues | What is next |
| Project status update | Short written "where we are" | The weekly glance |

**Milestone naming (one project per repo).** `<Epic> N: <Outcome>` for live phases (`Recipes 2: The Sunday ritual`), plus two shelves per epic: `<Epic>: hardening` and `<Epic>: later`. Cross-cutting work uses `Platform: hardening` and `Later: deferred`. The shared prefix lets one "milestone name contains <Epic>" filter show the whole epic. Outcomes, not internal codes. 3 to 6 live milestones per epic; split one that passes ~12 open issues. Match milestones by ID or epic prefix, never by exact full name... names get refined.

**Issue creation contract.** No agent creates an issue without setting all four: **project, milestone, priority (never "No priority"), one `flow:*` label**. If no milestone fits, create or pick one and say so in one line. "No milestone" is never valid.

- **Residuals go home:** a review residual is filed into the `<Epic>: hardening` milestone of the epic that produced it (the parent issue's epic). Create the milestone if missing.
- **Parked work has a shelf:** deferred ideas go to `<Epic>: later`, priority Low, label `deferred`. Work sitting in a live milestone never carries `deferred`.
- **Children inherit:** sub-issues take the umbrella's milestone and get an explicit priority. A plan-type umbrella `blocks` its children.
- **Order is structure:** if a description says "before", "after", "blocks", or "must land first", also write the blocking link. Every milestone description starts with two lines, kept current by whichever agent changes the order:

  ```
  Outcome: <what the user can do when this is done>
  Order: MCR-a → MCR-b → (MCR-c, MCR-d in parallel) → MCR-e
  ```

- **Superseding a plan means closing it out:** when a PRD refresh replaces a phase, re-home every open issue into a live milestone or cancel it with a comment. Never rename a milestone "Historical" and leave open issues inside. Put scope changes into structure (milestone, labels, links), not only into the description.
- **Labels are not structure:** never invent labels that mirror milestones (`mvp:c1`). Labels carry cross-cutting facts only: `flow:*`, `design:*`, `tier:*`, `gate:human`, `prd-source`, `spec-ready`, `sort:needs-answers`, `Bug`, `ops`, `deferred`.
- **Duplicates:** before filing, search open issues on the same file or module. Extend the existing issue instead of filing a near-copy.

**Hygiene check (read-only, targets all zero).** Run at session close and on status; print the counts every time:

1. open issues with no milestone
2. open issues with no priority
3. open issues with no `flow:*` label (exempt: issues in a `later` / `deferred` shelf, labeled at pull-down)
4. open issues inside a milestone marked historical or superseded
5. live milestones whose description lacks the `Outcome:` / `Order:` header

If non-zero, fix what this session created and list the rest. Never bulk-fix issues the session did not create without saying so.

**Status for the human.** At session close, post a Linear **project status update** (not only an issue comment): shipped, next, blocked, anything needing Zack. Three to six lines, plain words.
