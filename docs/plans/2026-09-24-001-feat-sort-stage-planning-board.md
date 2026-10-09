# Plan: The Sort stage and the Planning board

- **Created:** 2026-09-24 (reviewed and tightened the same day)
- **Tier:** judgment (process design); build units moderate
- **Linear Project:** Workflow (milestone "Sort: wake up to a planning board that says what each issue needs"), Pulse (milestone "Plan: open Build and see what each issue needs before tonight")
- **Linear Issues:** MCR-1796, MCR-1797, MCR-1799, MCR-1800, MCR-1801
- **Task:** An agent decides overnight what planning and design each open issue needs, so the daily hour starts from a board instead of from reading issues.

---

## 1. Why

- The backlog is 250+ open issues. Nothing on them says "no UI, just plan it" vs "mock screens X and Y" vs "map a new journey". `flow:*` is rigor; `spec-ready` is done; the middle is empty.
- Most of it needs no design. The Pulse trial: 12 of 23 no design, 7 small visible tweaks, 4 new screens. The sort's main job is to fill the tank fast and point your attention at the few issues with screens.

## 2. The runbook (hand this to anyone)

**Night, before `/factory` (agent, one scheduled job, all projects).**
1. **Sort** every open issue (Backlog, Todo) that has no `design:*` label, is not `spec-ready`, `deferred` or `ops`, plus any issue edited since its sort card.
2. For each, write one `design:*` rung, `flow:*` only if missing, `sort:needs-answers` if it cannot be placed, and one **sort card** comment, edited in place.
3. Never plan, build, change status, or close anything.

**Morning (you).** Verify first, as today (Stage 7). Then the **daily hour** opens on Pulse > Build > Planning:
1. **Tank check.** The gauge shows spec-ready vs tonight's appetite. Tank low means plain work first (the existing "Tank first" rule).
2. **Answer questions** on `sort:needs-answers` cards by replying in the sort card's thread in Linear (or in chat, and the agent posts the reply). The next night re-sorts them. You find out from the **morning brief** ("N issues need your answers", counted from Linear, omitted at zero; MCR-1699) and the **Pulse board** header and first column (MCR-1801). No Linear notifications. Queue: the Linear view **Needs answers** (Favorites in the sidebar; filter = label `sort:needs-answers`, not `deferred`), until the Pulse board replaces it.
3. **Plan the plain ones** (Plan only column): `/ce-plan`, then `/packets`. Several per hour is normal.
4. **One design block** on Today's pick, using its rung's recipe (section 3).
5. **Close:** labels true, canvas link on the issues, tank fuller.

**Rule of one:** one design group per hour. Plain plans can be several.

## 3. The five design rungs

The sort picks the first rung that fits, from the top. This table **replaces** the MANUAL's Stage 2 "When to run a design session" rubric, so there is one rule, not two.

| Rung | Fits when | Recipe | Time |
|---|---|---|---|
| `design:product` | A new app. Nothing existing to extend | `/design-consultation` if no design system; Claude Design: directions (2 to 4 variants) on the magic screen, the 3 to 5 core-loop screens, full walk-through, sketch summary (Stage 3). Then `/caspian` | 1 to 2 hours |
| `design:journey` | Inside an existing app: 3+ connected new screens, a new interaction model, new navigation, the core loop's screens change, or a surface users will form a habit on | Claude Design in the repo: directions on the key screen only, one artboard per step, walk-through screen by screen, sketch summary (Stage 3) | 1 hour |
| `design:screens` | 1 or 2 new screens or panels, or more than half of one screen changes | Claude Design in the repo: one artboard per named screen plus the core screen's empty, loading and error states. No directions unless the layout is truly open. No walk-through | 20 to 40 min |
| `design:tweak` | A user would **see** a change on an existing screen whose layout survives (field, state, button, copy, mobile fix) | No mockup. Before-screenshot and the change as acceptance criteria in the packet. Morning verify compares | 0 to 5 min |
| `design:none` | Nothing visibly changes: infra, data, API, jobs, tests, docs, behavior-only bug fixes | Straight to `/ce-plan`, or the `/lfg` plan gate on `flow:ship` | 0 |

- **Walk every screen step by step:** only on `journey` and `product`.
- **Variants (design shotgun):** only where the layout is open. Always on `product`, the key screen on `journey`, never below. Done inside Claude Design as "directions".
- **Where designs live:** one Claude Design canvas per group, opened inside the repo so it uses real components. Link it on every issue in the group. Chat mockups are not the contract.
- **Spec-ready gate:** an issue on `screens`, `journey` or `product` needs its canvas link before it can be `spec-ready`.
- **Helpers:** Mobbin for how other apps solve a screen; `/plan-design-review` on the plan to catch missing states.

## 4. The sort card

One comment per issue, edited in place, never duplicated:

```
Sort card (2026-09-24, confidence: high, weak spot: none)
What it is: <one plain sentence>
Design: design:screens
Screens to mock: 1) Deep Work detail panel  2) Session-start prompt
Tool: Claude Design (pulse repo), one artboard each + empty state
Group: MCR-1703 (same Day view). Duplicate of: none
Next step: design block, then /ce-plan, then /packets
Questions: none
```

- **Weak spot** names the readiness gap: problem, acceptance, context, or risk.
- **Questions** can appear on a placed issue when they do not block the rung.
- **Next step** says "cancel candidate: <why>" when another issue has overtaken this one. Age alone (60+ days) only flags it.
- Name the owning repo in **Tool** when the work lives outside the project's main repo.

## 5. Labels

- `design:none | tweak | screens | journey | product`. Any `design:*` label means the issue is sorted.
- `sort:needs-answers` when it cannot be placed confidently.
- No other new labels. (`sort:done` was created, then retired in review as redundant.)

## 6. The Planning board (Pulse > Build > Planning)

- **Header:** tank gauge and Today's pick. Pulse **computes** both from Linear data (labels, relations, milestone, priority, age, the card's Group line), so the sort job stores nothing extra.
- **Today's pick ranking:** tank low → cheapest group to make ready; otherwise unblocks-most → current milestone → priority → age. A group = issues that change the same screens.
- **Columns:** Needs answers · Plan only (`none`, `tweak`) · Mock up (`screens`) · Map the journey (`journey`, `product`) · Stalled (In Progress > 7 days, In Review > 3 days) · Ready (`spec-ready`) · Not sorted yet.
- **Card:** ID, project, what it is, rung, screen names, tool, group. Click opens Linear.

## 7. Capture

`/buildnote` stays one line. Nobody sets a rung at capture. The sort does it, and asks back through `sort:needs-answers` when it cannot.

## 8. Rollout

1. MCR-1796 runbook first (the job reads its rules from there).
2. MCR-1797 nightly job, starting with Pulse only. Each morning you skim that project's cards; the next project joins the allowlist the night after. This is the backfill; there is no separate backfill job.
3. MCR-1801 board, once cards exist across two or three projects.
4. MCR-1799 rename, any time.
5. MCR-1800 overnight plan drafts, deferred until the cards are trusted (re-price 2026-10-15).

## 9. Research decision: extend

- Matt Pocock's `/triage` (aihero.dev/skills-triage): needs-info loop, durable briefs. Borrowed the loop and the durable wording.
- Anthropic's claude-code-action: one triage comment edited in place. Borrowed.
- GitHub Spec Kit: `/clarify` as the question gate before planning. Borrowed the name.
- arXiv 2512.21426 (issue readiness for Copilot): five readiness dimensions. Borrowed as the card's "weak spot".
- No public rubric exists for "how much design does this issue need". The rung table is ours.

## 10. Decisions log

- 2026-09-24: sort runs nightly as one job across projects, before `/factory`.
- 2026-09-24: five rungs.
- 2026-09-24 review: `design:flow` renamed `design:journey` (it read as the reverse of `flow:design`); `sort:done` retired (a `design:*` label already says "sorted"); `tweak` moved to the Plan only column (it needs no mockup); Today's pick and the gauge computed in Pulse; backfill folded into the job's rollout (MCR-1798 canceled); the rung table replaces the old design-session rubric; Linear onboarding issues MCR-1 to MCR-4 canceled.
- 2026-09-25: sort on touch. The first planning step that meets an unsorted issue (`/ce-plan`, `/caspian`, `/packets`) sorts it inline with the same rules, label and card. The nightly job becomes the backup sweep for untouched issues and re-sorts.

## 11. Trial (Pulse, 23 issues, 2026-09-24)

none 12, tweak 7, screens 4. 17 placed, 6 need answers. No write failures. Pick: Desk API hardening, MCR-1759 first. Rubric fixes from the trial are already folded into sections 3 and 4.
