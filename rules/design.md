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

`sort:needs-answers` means the sort could not place the issue; its **sort card** comment carries the questions. **Sort on touch:** an issue with no `design:*` label is unsorted. The first planning step that touches it (`/ce-plan`, `/caspian`, `/packets`) sorts that one issue before planning it, using SORT.md Steps 2 to 4: read it, pick the rung, write the label and the sort card (the Planning board and the nightly job read the card, so never skip it). State the rung in one line. `none` or `tweak` → carry on. `screens`, `journey`, or `product` → the spec gate below applies: flag it when it has no canvas, and write no plan for it yet. Cannot place it → `sort:needs-answers`, print the questions, and stop on that issue.

**Spec gate:** an issue on `design:screens`, `design:journey`, or `design:product` may not be marked `spec-ready` until it has a **canvas link**... a Linear attachment, or a `Canvas: <url>` (or build packet `Artboard: <url>`) line in the description, pointing at the Claude Design (or Figma) canvas. Planning (`/ce-plan`, `/packets`, `/caspian`) that meets such an issue without one flags it and moves on (Design brief, below), and never invents the screens. The gate binds only issues that change what a user sees: a chunk is judged on its own file scope, so the back-end chunks of a `design:journey` parent are `design:none` and build without the canvas (`/packets` > Design gate).

**Design brief (flag it and move on):** a missing canvas never stops the session and never gets a bare pointer like "draw Canvas A". Write a **design brief** for the issue's group (issues that change the same screens) from `~/Developer/dev-workflow/factory/templates/design-brief.md`: app context, the DESIGN.md rules inlined, example content, one block per screen with what it must show, actions, next step, states and exclusions, the flow, and a "Done when" checklist traced to the issues' acceptance checks. Every file the canvas needs (DESIGN.md, reference screenshots, existing canvases) is committed in the repo, with any outside file copied into `docs/design/briefs/assets/<group-slug>/`, and listed in the brief by its full GitHub URL on the default branch. **Never tell Zack to attach files.** Name the group by what it is, never a letter. Save it to `docs/design/briefs/<group-slug>-YYYY-MM-DD.md` (commit it with the planning work; reuse and update an existing brief for the same group). On every issue in the group: add the `needs-canvas` label, add a `Brief: docs/design/briefs/<group-slug>-YYYY-MM-DD.md` line to the description (the path is the group's key), and post a one-line comment linking the brief. Then go to the next issue, and end the session with one line saying what joined the Design queue. Never wait for a reply. A canvas link Zack gives later (`canvas <url>`) goes on every issue in the group as `Canvas: <url>`, with a comment and `needs-canvas` removed.

**Labels:**
- `needs-canvas`: this issue changes what a user sees, its rung needs a canvas, and it has none.
- `canvas:agent`: an agent drew the canvas and Zack has not looked at it. Approving means removing it; on a held `journey` or `product` chunk, approval also adds `spec-ready`.

**Design queue (D-032):** one list of every open issue waiting on a canvas, for Zack to pick from. It is optional work, never an ask: nothing here files to `os.factory_asks`. Issues labeled `deferred` stay out.

| State | Test | Next move |
|---|---|---|
| No brief yet | `needs-canvas`, no `Brief:` line | Planning or the factory writes one |
| Needs canvas | `needs-canvas` with a brief | Zack draws it, or the night does |
| Draft to review | `canvas:agent` | Zack looks and approves or edits |
| Ready to plan | Canvas link, no packet | `/ce-plan`, then `/packets` |

**When the night draws a canvas:**

| Issue | After drawing |
|---|---|
| `design:screens`, packet finished | Add the `Canvas:` / `Artboard:` link and `canvas:agent`, clear `needs-canvas`, add `spec-ready`, build tonight |
| `design:journey` or `design:product`, packet finished | Add the link and `canvas:agent`, clear `needs-canvas`, no `spec-ready`. Draw directions on the key screen, without picking one |
| Any rung, no plan yet | Add the link and `canvas:agent`, clear `needs-canvas`. It shows as Draft to review, then Ready to plan. No build |

A failed draw leaves `needs-canvas` on, records a `no-canvas` skip with the reason, and the run moves on. It is never an ask or a stop.
