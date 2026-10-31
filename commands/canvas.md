---
name: canvas
description: The Design queue for this repo. With no argument, lists every group of issues waiting on a canvas. With a group name, draws a first canvas from its brief and writes the link to every issue in the group. Use for "/canvas", "what screens need a canvas", "draw the canvas for X", "approve this canvas". NOT for building the screens (/lfg, /factory) or for writing a plan (/ce-plan).
argument-hint: "[group name or brief path] (default: list this repo's queue)"
---

# Canvas

Planning flags a missing canvas and moves on. This command is how Zack picks one off in a working session. If he does not, `/factory` draws it as a last resort, using **Drawing** below. Rules, labels and states: `~/Developer/dev-workflow/rules/design.md`; why: D-032.

Read `.linear-project.json` at the repo root for the Linear project (monorepo: the app's own file). No link file → say so and name the plan's issues by hand.

## `/canvas`: list the queue

Read every open issue in the project with `needs-canvas` or `canvas:agent`, and every open issue on `design:screens`, `design:journey` or `design:product` with a canvas link and no build packet. Read each issue in full, one at a time: a listing cuts descriptions off, so a link can look missing. Leave out `deferred`.

Print one row per brief (the `Brief:` line is the group's key), most issues unblocked first:

| State | Test | Next move |
|---|---|---|
| No brief yet | `needs-canvas`, no `Brief:` line | Write one, then `/canvas <group>` |
| Needs canvas | `needs-canvas` with a brief | `/canvas <group>` |
| Draft to review | `canvas:agent` | Open the link, then approve or edit |
| Ready to plan | Canvas link, no packet | `/ce-plan`, then `/packets` |

Columns: group, rung, issues (IDs), issues unblocked, state, brief, canvas link. Issues unblocked counts the group's issues plus the open issues they block. Print and stop. Nothing here is an ask, and nothing is due.

## `/canvas <group>`: draw it

1. Find the brief by group name or path. None yet → write it (`rules/design.md` > Design brief), and add `needs-canvas` and the `Brief:` line to each issue.
2. **Draw** (below).
3. Give Zack the link and the brief's "Done when" list. He edits on the canvas, or tells you what to change. On `journey` and `product` he picks one direction before the rest is drawn.
4. **Write the link** to every issue in the group when he is happy: a `Canvas: <url>` line in the description (a chunk's `Artboard:` line if it has one), one comment with the link, and `needs-canvas` removed. No `canvas:agent`: he has looked at it. A chunk with a finished packet also gets `spec-ready`.

**Approving a draft.** On a group in Draft to review, open the link and let him look. Approval removes `canvas:agent` from every issue in the group. On a held `journey` or `product` chunk, it also adds `spec-ready`.

## Drawing

Shared with `/factory` Step 3c, which runs it with nobody there. Never ask a question in this section: decide, and state the assumption in a line.

1. **Read the brief** and the repo's `DESIGN.md`.
2. **Create a Design artifact.** Artifact tool, `action: "quickstart"`, `intent: "design"`, `design_systems: false`, then follow what it returns. Title it `<Project> · <group name>`.
3. **Name the design file.** Follow the repo's `DESIGN.md`, not the account's default design system. No `DESIGN.md` → say so in one line and use the current screens as the reference.
4. **Draw what the brief lists:** one artboard per screen, in order, with the states it names. `journey` and `product`: on the key screen, draw the directions the brief names, without picking one. `screens`: the core screen's empty, loading and error states instead.
5. **Report the URL.** It is private to Zack's account.

**Which lanes can draw.** Claude can: tested 2026-10-31 (plan `docs/plans/design-queue-agent-canvas-2026-10-31.md` > Unit 0). A builder reads a canvas through the Artifact tool, as `project/canvas.json` and `project/*.dc.html`; fetching the link proves nothing. Codex cannot read one. Cursor is untested. Where the Artifact tool is missing, in a working session: draw HTML, commit it to `docs/design/canvas/`, and link its full GitHub URL. A bare path does not count as a canvas. With nobody there, the night skips as `no-canvas`.

A failed draw leaves `needs-canvas` on. Say why in one line. It is never an ask or a stop.
