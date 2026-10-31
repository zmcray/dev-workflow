# Plan: The Design queue and agent-drawn canvases

- **Created:** 2026-10-31
- **Tier:** judgment (process design); build units moderate
- **Linear Project:** Workflow (rules, factory, skill); Pulse (the queue view)
- **Linear Issue:** MCR-3877 (umbrella; chunks listed under Chunks). MCR-1801 (deferred Planning board) stays deferred and is blocked by U5b.
- **Task:** Every screen that needs a canvas shows up in one list Zack can pick from. If he has not drawn one and it is the only thing holding work back, the factory draws it.

---

## 1. Why

- **A missing canvas stops work and nobody can list it.** The link lives in issue text, so Linear cannot filter on it. Briefs sit in 5 repos (34 files) with no shared list.
- **The factory cannot see the waiting work.** `/packets` withholds `spec-ready` when a canvas is missing, and the factory's queue only reads `spec-ready`.
- **Planning stops and waits for a reply.** The handoff depends on Zack pasting a prompt, then typing `canvas <url>`.
- **The handoff expires.** Standalone Claude Design closes by December 14, 2026. Design is now an Artifact type in Claude, which an agent can create. MCR-2350 already links one.

## 2. Decisions

| Decision | Choice | Why |
|---|---|---|
| Where the rule sits | Both: planning flags, the factory draws as a last resort | Planning knows first; the night is the backstop |
| Same-night build | `design:screens` draws and builds. `design:journey` and `design:product` get a draft and wait for Zack (user decision, 2026-10-31) | Choosing a direction is a human call, and a wrong one wastes a night and a revert |
| Where he sees it | One Design queue in Pulse's Build tab, all repos, with a per-repo filter. A saved Linear view until it ships | A second board would be a second thing to check |
| Not an ask | The queue never files to `os.factory_asks` | It is optional work to pick from, and D-031 just cut asks down |
| Night cap | At most **2 groups** per run, most issues unblocked first; a budget setting can change it | Keeps drawing from eating the night. Tune after two weeks |

## 3. How it works

**Labels (added to the list in `rules/linear.md`):**
- `needs-canvas`: this issue changes what a user sees, its rung needs a canvas, and it has none.
- `canvas:agent`: an agent drew the canvas and Zack has not looked at it.

**Group line:** every issue in a group gets `Brief: docs/design/briefs/<group-slug>-YYYY-MM-DD.md` in its description. The brief path is the group's key, so Pulse can group without reading comments.

**States of a row in the queue:**

| State | Test | Next move |
|---|---|---|
| No brief yet | `needs-canvas`, no `Brief:` line | Planning or the factory writes one |
| Needs canvas | `needs-canvas` with a brief | Zack runs `/canvas`, or the night draws it |
| Draft to review | `canvas:agent` | Zack looks and approves or edits |
| Ready to plan | Canvas link, no packet | `/ce-plan`, then `/packets` |

Issues labeled `deferred` stay out of the queue.

**Three paths:**
1. **Planning:** meets a missing canvas, writes the brief, adds the label and the `Brief:` line, then moves to the next issue. It no longer ends the session waiting.
2. **Working session:** `/canvas` with no argument lists this repo's queue. `/canvas <group>` draws a first canvas from the brief, Zack edits it, and the skill writes the link to every issue in the group and clears `needs-canvas`.
3. **Night:** the factory reads `needs-canvas` issues with no `gate:human`, not `ops`, not `deferred`, and no open blocker, then draws up to the cap.

**What the night does after drawing:**

| Issue | After drawing |
|---|---|
| `design:screens`, packet finished | Add the `Canvas:` / `Artboard:` link and `canvas:agent`, clear `needs-canvas`, add `spec-ready`, build tonight |
| `design:journey` or `design:product`, packet finished | Add the link and `canvas:agent`, clear `needs-canvas`, no `spec-ready`. Draw directions on the key screen, without picking one |
| Any rung, no plan yet | Add the link and `canvas:agent`, clear `needs-canvas`. It shows as Draft to review, then Ready to plan. No build |

Approving a draft means removing `canvas:agent`. On a held journey or product chunk, approval also adds `spec-ready`.

**If drawing fails:** the issue keeps `needs-canvas`, the ledger records a `no-canvas` skip with the reason, and the run moves on. A failed draw is never an ask or a stop.

## 4. Units

### Unit 0: Test unattended drawing (do this first; it can change Units 2 and 3)

Run from a headless session under the factory's own permission mode, against a throwaway brief:
- Can it create a Design artifact from the type, publish files to it, and get a URL back, with no prompt or login?
- Can it pick up the repo's `DESIGN.md` instead of the account's default design system?
- Can a builder read the canvas back on each lane: Claude, Codex, Cursor?

**Fallback if any answer is no:** draw HTML and commit it to `docs/design/canvas/`, then link it by its full GitHub URL. MCR-2967 already does this. A bare path does not count as a canvas: the 2026-10-29 Pulse run skipped MCR-2466 and MCR-2467 for it.

Done when: the answers and the chosen path are written here, per lane.

**Results (2026-10-31, on this Mac):**

| Lane | Draws with no prompt or login | Uses the repo's `DESIGN.md` | Reads a Design artifact | Path |
|---|---|---|---|---|
| Claude (`claude -p`, auto mode) | Yes: created, published, URL back, no denials, 52 seconds, $0.88 | Yes, when the prompt names it | Yes: a fresh session read the timer text, label and background color from the source | Design artifact |
| Codex (`codex exec`, approval never) | Untested | Untested | **No.** Its browser needs an approval for claude.ai, and nobody is there to give it | Fallback: HTML in `docs/design/canvas/`, full GitHub URL |
| Cursor | Untested: no `cursor-agent` command here, only the app | Untested | Untested | Fallback until tested. The lane is not built (MCR-1412) |

What this means for the later units:
- **Name the design file.** The Design type uses the account's default design system unless the session names another. Every draw prompt must name the repo's `DESIGN.md`.
- **Read the source, not the page.** A builder reads `project/canvas.json` and `project/*.dc.html` through the Artifact tool. A plain fetch of the link returns 200, which proves nothing about the canvas.
- **A Design artifact builds only on the Claude lane.** Until Codex can read one, a chunk with a Design artifact canvas skips on Codex as `no-canvas`.
- **Not covered:** the other Mac, and a scheduled night start. Both sessions were started by hand from this Mac's login. Unit 4's real night covers the scheduled start.

Test canvas, left in place and private: https://claude.ai/artifact/WH3vpyYqk76NkPU1AwQaw8

### Unit 1: Rules, labels and the stopgap view

- `rules/design.md`: the new planning behavior, the labels, the `Brief:` line, and the rung table above.
- `rules/linear.md`: add both labels. Create them in Linear.
- `factory/SORT.md`: the nightly sort reads each issue's full description (the listing cuts text off), adds `needs-canvas` when a rung needs a canvas and none exists, and removes it when a link appears. The sort still plans and builds nothing.
- `commands/packets.md` (Design gate) and `caspian/linear-write.md`: add the label and the `Brief:` line, and end with one line about the queue instead of "Your steps".
- `factory/MANUAL.md`: stages 3 and 5, and the Zooming in table. Check whether `docs/software-factory.md` is still current, and fix or leave it accordingly.
- `factory/DECISIONS.md`: record as D-032.
- One-time sweep across all projects, then a saved Linear view of `needs-canvas`, grouped by project.

Done when: the view lists every open issue missing a canvas, and spot checks of 10 issues match.

### Unit 2: The factory draws

- `commands/factory.md` Step 2: add the second query. New step after the ledger opens: draw up to the cap, and write a brief first if none exists. Newly ready `design:screens` chunks join tonight's queue.
- Journey and product chunks carrying `canvas:agent` are skipped as `canvas-draft`, even if someone labels them `spec-ready` by hand.
- Ledger: a `canvases` list. Morning review: `Canvases drawn:`, listing what was built on an agent canvas. It replaces `Needs design first:`.
- `rules/goal-runs.md`: the same rules, so a goal run does not disagree with a factory run.
- Lanes that Unit 0 shows cannot draw keep skipping these issues as `no-canvas`.

Done when: a test project with one `screens` chunk and one `journey` chunk ends with the first built and the second drafted and waiting.

### Unit 3: The `/canvas` skill and the new brief (due before December 14, 2026)

- `commands/canvas.md`, shipped by `deploy-skills.sh`: the two forms in section 3. Do not use `/design`.
- `factory/templates/design-brief.md`: replace "open Claude Design and paste" with `/canvas <group>`. Keep the screen blocks, since they are what the agent draws from. Keep "Done when".
- Remove the `/design` and paste steps from `factory/MANUAL.md`.

Done when: `/canvas` turns a real brief into a canvas, and the link lands on every issue in the group.

### Unit 4: A first real run

Run the sweep's output through `/canvas` on one group from Pulse, then let one factory night draw one `screens` group. Read both results before widening.

Done when: Zack says the canvases are good enough to build from, or the brief template changes until they are.

### Unit 5: The Design queue in Pulse (needs its own canvas: the first item in the queue)

- `api/_linear.js`: pull issues with `needs-canvas` or `canvas:agent`, and those with a canvas link but no packet, across all projects.
- `src/views/`: the queue in the Build tab, with one row per group: name, repo, rung, issues unblocked, state, brief and canvas links. Most unblocked first. Per-repo filter.
- MCR-1801 stays deferred for the rest of the board, to be re-scoped against this queue before anyone builds it.

Done when: every row matches the Linear view on fixture data, and there is no sideways overflow at 375px.

## 5. Risks

- **Weak drawings build faithfully.** The canvas is the build contract. `canvas:agent` and the morning line are the safety net, and Unit 4 is the check.
- **Labels can drift from the text.** The nightly sort reconciles them each night, and the link stays the source of truth.
- **Night time goes to drawing.** The cap limits it, and the ledger shows the cost.
- **Lanes differ.** A canvas one lane cannot read blocks a chunk built on that lane. Unit 0 answers this before anything depends on it.
- **The December 14 date is fixed.** If everything else slips, Unit 3's template change still has to land.

## Chunks

| Unit | Issue | Wave | Landing group | Tier |
|---|---|---|---|---|
| U0 | MCR-3878 | 1 | Design queue U0 | judgment |
| U1a | MCR-3879 | 1 | Design queue PR 1 | moderate |
| U1b | MCR-3880 | 2 | Design queue PR 1 | moderate |
| U2 | MCR-3882 | 2 | Design queue PR 2 | judgment |
| U3a | MCR-3883 | 2 | Design queue PR 3 | moderate |
| U1c | MCR-3884 | 3 | no PR (Linear only) | moderate |
| U3b | MCR-3885 | 3 | Design queue PR 3 | mechanical |
| U1d | MCR-3886 | 4 | no PR (`gate:human`) | mechanical |
| U5a | MCR-3887 | 4 | Design queue Pulse PR | moderate |
| U4 | MCR-3888 | 4 | Design queue U4 (`gate:human`) | judgment |
| U5b | MCR-3889 | 5 | Design queue Pulse PR | moderate |

U1 split into four along its files and its human step. U5 split into data and screen, so the data chunk can build without a canvas. U5b is not `spec-ready`: U4 writes its brief and draws its canvas. Writing the brief now would use the template U3b replaces.
