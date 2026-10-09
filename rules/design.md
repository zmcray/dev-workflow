<!-- Moved from the canonical AGENTS.md block (MCR-2720). Read on demand; binding when it applies. -->

# Design rung, spec gate and design brief

For any planning step (`/ce-plan`, `/caspian`, `/packets`) and any `design:screens`, `design:journey` or `design:product` issue.

## Design rung (how much drawing before planning)

Every open issue also carries exactly one `design:*` label. The first planning step that touches an unsorted issue sets it (sort on touch, below); the nightly sort is the backup sweep for issues nobody has touched. Rules for both: `~/Developer/dev-workflow/factory/SORT.md`. Planning may overrule a rung in one line. It is a separate axis from flow: flow is how much rigor, the rung is how much drawing happens before the plan.

- `design:none` ... nothing a user sees changes: infra, data, API, jobs, tests, docs, behavior-only bug fixes.
- `design:tweak` ... a visible change on an existing screen whose layout survives. No mockup: the before-screenshot and the change go in the acceptance criteria.
- `design:screens` ... 1 or 2 new screens or panels, or more than half of one screen changes.
- `design:journey` ... inside an existing app: 3+ connected new screens, a new interaction model, new navigation, the core loop's screens change, or a surface users will form a habit on.
- `design:product` ... a new app with nothing existing to extend.

`sort:needs-answers` means the sort could not place the issue; its **sort card** comment carries the questions. **Sort on touch:** an issue with no `design:*` label is unsorted. The first planning step that touches it (`/ce-plan`, `/caspian`, `/packets`) sorts that one issue before planning it, using SORT.md Steps 2 to 4: read it, pick the rung, write the label and the sort card (the Planning board and the nightly job read the card, so never skip it). State the rung in one line. `none` or `tweak` → carry on. `screens`, `journey`, or `product` → the spec gate below applies: design first, before the plan is written. Cannot place it → `sort:needs-answers`, print the questions, and stop on that issue.

**Spec gate:** an issue on `design:screens`, `design:journey`, or `design:product` may not be marked `spec-ready` until it has a **canvas link**... a Linear attachment, or a `Canvas: <url>` (or build packet `Artboard: <url>`) line in the description, pointing at the Claude Design (or Figma) canvas. Planning (`/ce-plan`, `/packets`, `/caspian`) that meets such an issue without one stops at "design first" and never invents the screens.

**Design brief (the design-first handoff):** "design first" is never a bare pointer like "draw Canvas A". Before stopping, write a **design brief** for the issue's group (issues that change the same screens) from `~/Developer/dev-workflow/factory/templates/design-brief.md`: a numbered "Your steps" list, a self-contained "Prompt to paste" into Claude Design (app context, the DESIGN.md rules inlined, example content, one block per screen with what it must show, actions, next step, states and exclusions, the flow), and a "Done when" checklist traced to the issues' acceptance checks. **Never tell Zack to attach files to Claude Design.** Every file the canvas needs (DESIGN.md, reference screenshots, existing canvases) is committed in the repo, with any outside file copied into `docs/design/briefs/assets/<group-slug>/`, merged to the default branch before the hand-off, and listed in the prompt by its full GitHub URL on the default branch, so Claude Design opens them itself. Name the group by what it is, never a letter. Save it to `docs/design/briefs/YYYY-MM-DD-<group-slug>.md` (commit it with the planning work; reuse and update an existing brief for the same group), post a one-line comment on every issue in the group linking the brief, then **stop**: print the table and "Your steps" in full as the last thing in the session, and wait. When Zack replies `canvas <url>`, add `Canvas: <url>` to each issue in the group, comment the link, and resume planning where it stopped.
