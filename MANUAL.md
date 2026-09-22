# The McRay Software Factory

*Operating manual — how work moves from a spark to a shipped, verified feature. Heavy hands up front, no hands at night.*

**The principle.** The front of the line is judgment, and it's yours: what to build, what it looks like, what the first usable version is. The back of the line is execution, and it belongs to agents and loops. Every stage has an exit gate. The gates are what keep blue-sky thinking — which is welcome, and captured — from leaking into tonight's build.

**Three kinds of time.** *The daily hour* (one calendar hour every day whose only job is to keep the tank full for tonight). *Nights* (agents build until the queue or the budget runs out). *Mornings* (20–30 minutes of verification). Two of the daily hours each week are **mapping days** (pull ideas, shape, draw, commit); the rest are **spec days** (cut committed work into small chunks). Sunday's hour ends with Learn.

**Tank first.** Every daily hour opens with a 2-minute tank check: is the `spec-ready` queue at least tonight's appetite? If not, today is a spec day no matter what the calendar says. Mapping is what you do when the tank is already full. There was never enough room to do bet → shape → design → commit → spec in one Thursday; the line is the same, it is just spread across the week.

**What actually runs it (2026-09-21).** Compound Engineering is the engine: `/ce-plan`, `/lfg`, `/ce-work`, `/ce-code-review`, `/ce-compound`. Claude Code's built-in `/goal` is the hands-off runner. The house layer is two commands: `/caspian` (the council) and `/packets` (plan → Linear chunks, invoked automatically). `/zmcray-kickoff` survives only because `/caspian` calls it to wire a brand-new repo. Everything else that used to be a `zmcray-*` command is now a rule in AGENTS.md: `/lfg` never touches Linear and never merges, so merge-on-green, Linear sync, and session close come from the rule file. One tool per job: `/caspian` to decide, `/ce-brainstorm` to think through one fuzzy feature, `/ce-plan` to make it buildable.

---

## 1. The line at a glance

| # | Stage | Who | When · timebox | Runs on | Produces | Exit gate |
|---|---|---|---|---|---|---|
| 0 | **Capture** | You | anytime · 30 s | `/buildnote` | `Stage: Idea` issue | none — it's a shelf |
| 1 | **Bet** | You | mapping day · 15 min / project | the Linear idea shelf, read against the product's `STRATEGY.md` | bets + this week's appetite | bets ≤ appetite |
| 2 | **Shape** | You + Claude | mapping day · 30–60 min / bet | conversation, `/office-hours`, `/diagram`, `/hagen` | shape doc | loop sentence in one line; dominant risk named; design session yes/no decided |
| 3 | **Design session** | You drive, Claude Design draws | a mapping-day hour (or two) · when triggered | `/design` canvas (or Figma/Excalidraw) | screens + flow + actions canvas; sketch summary | walk-through passed; verdict = keep |
| 4 | **Commit** | You + the council | mapping day · ~1 h (PACKET: 30 min) | `/caspian` v3 | PRD with Later Shelf; labeled issues | Red Team adjudicated; M1 = skeleton only |
| 5 | **Spec** | Agent; you for taste calls | spec days · the daily hour | `/ce-plan` → `/packets` | `spec-ready` chunks | queue ≥ appetite; every issue ≥ 7; plans landed |
| 6 | **Build** | Agents | nights | built-in `/goal` → `/lfg` per chunk | merged PRs, residuals, nightly build, morning checklist | green train; hard stops surfaced, not guessed |
| 7 | **Verify** | You | mornings · 20–30 min | checklist, `/ios-qa`, `/qa-only`, `/design-review` | issues closed or kicked back | In Review pile = 0 |
| 8 | **Learn** | Agent-led, you read | Sun · 20 min | `/ce-compound`, `/retro` | learnings promoted; board synced | AGENTS.md / templates updated |

---

## 2. Stage walk-throughs

### Stage 0 — Capture

**Purpose.** Big-sky thinking comes when it comes. It gets a home that is not the pipeline.

**You do.**
1. `/buildnote <project> — <idea>`. Thirty seconds. It lands as `Stage: Idea` on the project's backlog. Never categorize further.
2. For a riff that wants an hour: run `/caspian` and take the exit that already exists — *"stop at the PRD doc."* The scaled vision gets written into the PRD's **Later Shelf**. Nothing is wired, no issues are created.

**Rules.** Parking-lot physics: the shelf is expected to be big, it holds one-liners not specs, and it is groomed only at Stage 1. A capture session may never create `spec-ready` issues or touch an active milestone.

---

### Stage 1 — Bet (mapping day, 15 minutes per active project)

**Purpose.** The only door from the shelf into the line. Ideas enter work here and nowhere else.

**You do.**
1. Open the project's `Stage: Idea` issues next to its one-page `STRATEGY.md` (`/ce-strategy` writes it once; revisit quarterly). The page is the yardstick: most ideas clearly serve one of its tracks or clearly do not.
2. For each: **bet** (enters this week's scope), **park** (untouched), or **kill** (cancel with one line of why). Five minutes, hard cap.
3. State the week's **appetite** per project before any scoping: *"Motus: one weekend, ~6 issues. Saidso: two nights."* Appetite is a time budget, not an estimate — scope gets hammered to fit it, never the reverse.

**Gate.** Bets fit the appetite. If they don't, park the weakest until they do.

---

### Stage 2 — Shape (mapping day, 30–60 minutes per bet)

**Purpose.** Turn a bet into something a design session or a council can act on, and decide which it needs.

**You do.**
1. Write the **loop sentence**: *"[user does X] → [magic Y appears]."* Can't write it in one sentence? It goes back to the shelf — it isn't shaped yet.
2. `/diagram` the **spine**: 5–8 journey steps, mile wide, inch deep. Mark the top row — the walking skeleton, the thinnest end-to-end path through the loop. Everything below the line is visibly parked.
3. Name the **dominant risk** (Cagan's four): *value* (will they want it?), *usability* (can they work it?), *feasibility* (can we build it?), *viability* (should we?). Decide how to retire it **before** building:
   - usability or value → **design session** (Stage 3)
   - feasibility → a **spike**: throwaway branch, timeboxed, never merges, produces a one-paragraph finding
   - viability → `/hagen` (go/no-go) or the Caspian council (Stage 4)
4. Fill the **shape doc** (template in §7): problem, loop, spine, appetite, dominant risk + retirement plan, rabbit holes, no-gos (seeds for the Later Shelf). `/office-hours` when the question is product, not engineering.
5. **Decide the design session** with the rubric below.

**When to run a design session — run one if ANY of these is true:**

| Trigger | Example |
|---|---|
| New product | anything pre-M1 |
| New user-facing surface or screen | a Threads tab, a capture sheet |
| New navigation or information architecture | tabs → sidebar; a new root flow |
| The core loop's screens change | the magic screen gets a new shape |
| New interaction model | voice, camera, share-sheet, gestures, Lock Screen controls |
| A feature touches more than two screens | onboarding, sharing, settings that reach into flows |
| Something users will form a habit on | daily capture, morning brief |

**Skip it when ALL of these hold:** backend/infra only · `flow:ship` · polish or copy on an existing screen (that's `/design-review` at Stage 7) · a bug fix.

**Gate.** Loop sentence in one line, dominant risk named with a retirement plan, design session decided. A bet that can't pass this gate in an hour goes back to the shelf with a note — that's a win, not a failure.

---

### Stage 3 — Design session (a mapping-day hour or two, when triggered)

**Purpose.** Lock the product flow, the screens, the layout and the actions *as pictures you can look at and argue with* — before a word of PRD or a line of code. Wireframe fidelity until the verdict; hi-fi is a Build-stage cost.

**You do** (in Claude Design — `/design` in Claude Code — or Figma/Excalidraw; same steps, same output):

1. **Bring the shape doc.** Each spine step is a candidate screen. Run `/design` with a brief: product, loop sentence, spine, device, *wireframe fidelity*. Inside an existing app's repo it matches your real components and tokens automatically — then the session is about layout and flow, not brand.
2. **Directions (30 min).** 2–4 genuinely different low-fi artboards of the **moment-of-magic screen**, each on a named axis (one-screen vs stepped, dense vs airy, list-first vs canvas-first). Pick one. Once picked, it stays picked.
3. **Screens + flow (60–90 min).** In the chosen direction, one artboard per spine step. Organize the canvas into pages:
   - **Flow** — screens left→right in loop order; a sticky note on every transition: *trigger → destination*.
   - **States** — the core screen only: empty, loading, result, error, first-run.
   - **Shelf** — screens for later, visibly parked on the canvas. Parked ≠ deleted; it's there so the vision has a place to live.
   Every screen artboard carries one sticky note: **primary action · secondary actions · what happens next · what data is shown · what is deliberately not here.**
4. **Actions audit (15 min).** Every action on every screen must serve the loop or move to Shelf. Count taps from open to aha — budget **≤ 3** for a utility loop. Anything that adds a tap without adding to the magic is cut.
5. **Walk-through (20 min).** With Elisa, or yourself cold. **5-second test** on the magic screen: *"what does this do?"* Then narrate through the flow; write confusion down verbatim. If the flow has to be *felt* (timing, gestures), ask `/design` for the clickable-prototype form of the canvas. If it has to be felt *on device* (camera, voice, share sheet), run a throwaway feasibility spike on a scratch branch — never merged, one paragraph of findings.
6. **Verdict + summary.** **keep** → write the sketch summary (template in §7) to `docs/strategy/sketches/YYYY-MM-DD-<slug>.md` with the canvas link — this is what Caspian's gate reads. **reshape** → rewrite the loop sentence, re-run another evening. **kill** → back to the shelf with why. Killed sessions are cheap; that's the point.

**Rules.** Wireframe until the verdict. No code (spikes excepted, and they never merge). One evening. The canvas is editable by hand later — refine screens during Spec if a spec needs it, **never during Build**. The canvas is the contract the morning verification checks against.

---

### Stage 4 — Commit (mapping day, ~2 hours; may span two daily hours)

**Purpose.** The decision to build, made by the council against evidence.

**You do.**
1. `/caspian <topic>` (NEW for a product, EXPAND for a feature on an existing PRD). Its sketch gate (delta D8) pulls in the sketch summary; if there isn't one and the scope is user-facing, it will ask you to run Stage 3 or to log `no-sketch: <reason>` — choose deliberately.
2. State the **appetite** before scoping. Scope is hammered to fit.
3. Apply the **skeleton contract**: a feature enters M1 only if the core loop breaks without it. Everything else goes to the PRD's **Later Shelf** with a defer rationale and kill conditions. The shelf is where your expansive thinking lives — on paper, priced by real usage, re-entering only through REFRESH.
4. Adjudicate the **Red Team** and **Eng review** findings (cross-model via Codex, fresh context) in one batched round. Don't let ambition win a debate it didn't win in someone's hands.
5. Ship gate → issues land `spec-ready` with a build-packet stub, executable acceptance criteria, exactly one `flow:*`, one `tier:*`, and `prd-source`; Later Shelf items land as `deferred` with a kill condition and re-price date. Caspian verifies its own Linear write before it reports success.

**Gate.** The M1 issue list is the skeleton and nothing else; every other feature is on the shelf with a kill condition.

---

### Stage 5 — Spec (spec days, the daily hour; mostly agent)

**Purpose.** Fill the tank so the nights can run without you.

**You do.**
1. `/ce-plan` with the issue (and PRD, if there is one) as input. For anything user-facing or ambiguous, run `/grilling` first so the questions get asked before the plan is written, not discovered at 2 a.m. Then `/packets`: it turns the plan's Implementation Units into Linear chunks with build packets, file scope, blocking edges, and `tier:*` labels, and prints the waves.
1a. **Cut it small.** The unit of work is a **chunk**: one issue, one PR, well under an hour of agent time, about 5 files and 300 changed lines or fewer, 1–4 machine-checkable acceptance checks. See §2a. Small chunks review in minutes, fail cheaply, and run in parallel.
1b. **Declare file scope and tier on every chunk.** File scope decides what can run side by side; `tier:*` decides which model is worth paying for.
2. Apply the skeleton test again while planning — anything that snuck into M1 without breaking the loop is logged `deferred`, not `spec-ready`.
3. Quality gate ≥ 7 on every issue; dependency edges set; advisor pass applied; CI-impact sections where workflows change.
4. If a spec needs more screen detail than the canvas has, **edit the canvas now**, by hand, then finish the spec. Not during Build.
5. Stop when the `spec-ready` queue ≥ **tonight's** appetite plus one night of buffer. More is waste; less means the night stalls. The tank is topped up daily, not filled once a week.

**Gate.** Queue ≥ appetite, all ≥ 7, every chunk carries a file scope and exactly one `tier:*`, the waves are printed, plans/specs landed **before** any branch is cut. The nights pull only `spec-ready`; an empty queue means "plan first," never "wing it."

---

### Stage 6 — Build (nights; agents)

**Purpose.** Turn the queue into merged, smoke-tested, nightly-built software while you sleep.

**You do (before bed, one line):** `/goal <milestone or issue list>` — then walk away.

**Expect short nights.** You will rarely stage eight hours of work, and credits may run out first. Both are normal endings, not failures. The run stops cleanly on **queue empty** or **budget stop**; whatever is left stays `spec-ready` for tomorrow. Fallback order when one harness runs dry: Claude Code → Cursor cloud agents → Codex → pause. The `lane:*` label records who took it.

**The machines do.**
1. Pull the highest-priority unblocked `spec-ready` chunk; read its `tier:*` and pick the model from `DISPATCH.md`; run the flow's pre-work; hand to `/lfg`; PR.
1a. **Parallel where the plan allows it.** Every chunk in the current wave (unblocked, disjoint file scope) may be built at the same time by different agents, each in its own environment. **Build in parallel, merge one at a time:** rebase on fresh `main`, re-run the smoke gate, then merge. Today a `/goal` run works one chunk at a time; parallel waves arrive with the Cursor cloud lane (see §6).
2. **Per-issue gate = smoke** (build + unit + a 10–15-test smoke UI plan, ~5–8 min). Merge on green. Residuals filed. Next issue branches from fresh `main`.
3. **Train end = full suite**, once, on final `main`. Red → Urgent residual, fix-forward in the morning.
4. Cut the **nightly build** (TestFlight from `main`; Vercel preview for web), tag it, and emit the **morning verification checklist**: one block per merged issue, its acceptance criteria as checkboxes.
5. Checkpoint. Hard stops (red baseline, unmergeable PR, PRD kick-back, anything destructive) stop the run and surface to the morning — never guessed through.

**Rules.** Pipeline projects are never hand-built at night — they're queued. Risky paths (migrations, auth, payments, workflows, entitlements) trip the risk gate: they require `flow:design` and the cross-model review, or the PR fails. Freehand projects (see §5) are exempt from all of this by declaration.

---

### Stage 7 — Verify (mornings, 20–30 minutes)

**Purpose.** One batch pass closes the night's work. This is where grouping genuinely saves time — closure, not merging.

**You do.**
1. Read the overnight digest (Argus): what merged, what stopped, what's red, and the **human batch** (every `gate:human` issue, parked or queued, with its one-line ask).
2. Install the nightly build / open the preview.
3. Walk the checklist, one block per issue: **pass** → Done · **fail** → residual (priority, label) · **scope surprise** → a Caspian EXPAND comment on the issue, not a fix.
4. Ten minutes of `/design-review` (web) or `/ios-design-review` (iOS) on the new screens **against the canvas** — the canvas is the contract.
5. Triage residuals; note anything that smells like a learning for Sunday.
6. Work the human batch in one sitting: do each `gate:human` step, remove the label (or hand the chunk to `/lfg` if the rest is agent work), and note any packet that missed its gate... that is a `/packets` learning.

**Gate.** The In Review pile is zero at the end of the ritual, or each remaining item is explicitly parked with a reason.

---

### Stage 8 — Learn (Sunday evening, 20 minutes)

**Purpose.** Each week makes the next one easier.

**You do.**
1. `/retro` — read, don't write.
2. `/ce-compound` on anything solved this week that will recur.
3. Board sync: `/landing-report`; stale In Progress and project statuses get corrected here, not whenever.
4. Promote durable learnings into the canonical AGENTS.md block (this repo's `deploy-agents-md.sh` carries them to the fleet).
5. Glance at the loops' health: runner uptime, nightly pass rate, residual count trend. Set next week's appetite hints.

---

### Zooming in — planning and design time on work that already exists

Most planning blocks won't start from a new bet. They start from a backlog of issues, live PRDs, an In Review pile, and a residual tail. A zoom-in block is a **bet on existing work**: same gates, three depths.

**1. Find candidates (5 minutes — save these as Linear views per project):**

| View | Filter | What it means |
|---|---|---|
| Needs a design session | `flow:design` · not `spec-ready` · Backlog | design-flow work nobody has drawn yet |
| Needs a deep spec | `prd-source` · Backlog · priority ≥ High · not `spec-ready` | committed by a PRD, not yet executable |
| Needs a decision | In Review > 3 days, or In Progress > 7 days | stalled work is a scope or design problem wearing a status |
| Needs a REFRESH | `deferred` with expired kill conditions; any milestone whose In Review pile *is* its feature list | M1 was too big, or usage data arrived |

Rank by: unblocks the most (dependency fan-out) → closest to the core loop → priority → blast radius. Pick **one** PRD or **one** cluster of related issues per block, and say the appetite: *"this evening."*

**2. Choose the depth:**

| Depth | When | Run | Output |
|---|---|---|---|
| **PRD zoom** (REFRESH) | the milestone itself feels wrong — too big, wrong loop, stalled M1 | `/caspian refresh <prd>` under the skeleton contract: re-slice M1, shelf the rest (`deferred` + kill conditions), cancel or keep issues. If M1's *screens* are in question, run a design session first — the gate applies to REFRESHes that re-slice M1. | re-sliced PRD, issues re-labeled, Later Shelf populated |
| **Feature zoom** (design session on an issue cluster) | a `flow:design` issue or cluster is screen-heavy or introduces a new interaction model | Stage 2 shape *for the feature* (its own loop sentence + spine) → Stage 3 design session **inside the repo** (Claude Design matches the existing components and tokens automatically, so the session is about flow, layout and actions — not brand; start from the current screens, don't reinvent them) → sketch summary attached to the issues (Linear comment + `docs/strategy/sketches/`) → `/ce-plan` on those issues, then `/packets` | `spec-ready` issues with a canvas behind them |
| **Issue zoom** (spec deepening) | direction is clear, the issue is under-specified (< 7 on the executability bar) | `/ce-plan MCR-xxx` (or a deepening pass), then `/packets`; skeleton test if it claims M1 | one `spec-ready` issue |

**3. Close the block the same way every time.** The issue or PRD carries the artifact (sketch summary link, re-sliced milestone, or spec); labels reflect reality (`spec-ready` / `deferred` / Cancelled); the tank is fuller than when you started. A zoom-in that ends with a *new* idea instead of a sharper existing one went sideways — capture the idea (Stage 0) and come back.

**Rules.** One cluster per block. A zoom-in never expands a PRD — if it wants to, that's a logged Caspian EXPAND, not a side door. Stalled In Progress / In Review items are zoom-in candidates before they are build candidates.

**Candidates from the Jul 31 pull** (re-pull before a block — the board moves daily):

- **Saidso — PRD zoom.** M1 (MCR-818 / 820 / 822 / 826) sitting In Review *as a block* is the signal: re-slice against "type a phrase → the right photo appears." The Aug 6 seamless-capture PRD gets the design-session gate retroactively before MC1 builds.
- **Motus — feature zoom.** MCR-858 W1 + MCR-859 W2 (plan-the-week UI + Coach draft/replan flow): screen-heavy, `flow:design`, PRD-sourced — a textbook design session. Then the recovery cluster MCR-854–864, where T2 "Today recovery explanation" is the UI spine.
- **Acquired Taste — feature zoom.** MCR-803 Quick Taste (Urgent, `flow:design`) is the core loop's front door. MCR-850 / 852 Editorial Studio carry `flow:design` and *no priority* — decide or shelf.
- **Argus — feature zoom.** MCR-948 conversational voice briefings is a new interaction model — exactly the rubric's trigger.
- **Pulse — needs a decision.** MCR-740 / 742 In Progress since Jul 22.

---

## 2a. Chunks, waves, and tiers

**Chunk.** The smallest piece that still ships something checkable on its own. One chunk = one issue = one PR. Size bar: one fresh agent context, well under an hour, about 5 files / 300 lines, 1–4 acceptance checks. If you cannot say what it makes work in one sentence, split it. Do not split below the point where it can be verified alone.

**Wave.** Chunks with no blocker between them and no shared files. A wave can be built by several agents at once. `/packets` prints the waves. Overlapping file scope always gets a `blocked by` edge, which pushes the later chunk into the next wave. Shared hot files (schema, route index, `Package.swift`, lockfiles, generated types) count as overlap. Widen waves by prefactoring the shared seam first, then fanning out.

**Tier.** How hard the chunk is to get right. It is a label on the chunk; the model is chosen at dispatch from `DISPATCH.md`. Never write a model name in an issue.

| Label | The chunk is... | Model class |
|---|---|---|
| `tier:mechanical` | one obvious approach, pattern already in the repo | cheapest fast model |
| `tier:moderate` | familiar reasoning against a settled spec (most chunks) | mid tier |
| `tier:judgment` | novel, ambiguous, or has concurrency / security / data traps | frontier; candidate for `class:hard` |

If most chunks come out `tier:judgment`, the cut is too coarse. Split until the hard part sits in one or two chunks. A good plan is mostly mechanical and moderate... that is also what makes a limited credit budget go furthest.

**Gate.** Can the chunk finish with nobody at the keyboard? Most can. The ones that cannot get `gate:human` at spec time, and the packet's `Human gate:` line says what the person does and when. Triggers: a person must look at images or screens and judge them (not a pixel diff a script can run), credentials / 2FA / App Store / a vendor console, a physical device, a taste or naming call, someone outside the company. `ops` stays for issues that are *entirely* human work. Neither ever enters the night queue; the morning digest lists them as one batch so you sit down once, not six times. An agent that hits an unplanned human step at night parks the chunk (draft PR + label + comment) and keeps going.

**Five labels, five questions.** `flow:*` = how much planning rigor. `tier:*` = how smart a model. `class:*` = how much merge trust. `lane:*` = which harness took it. `gate:human` = a person has to be there.

---

## 3. Always-on loops (the machines)

| Loop | What it does | Status |
|---|---|---|
| **Runner health** | both self-hosted runners online, queued-job age, auto-`launchctl kickstart`, notify on stall; `caffeinate -s` pinned to the runner launchd services so the Air never sleeps through a queue | to build (30 min) |
| **Nightly full suite + watcher** | full XCUITest/regression on `main` nightly; red → Urgent residual filed; pass rate into the digest | to build |
| **CI babysitter** | inside every goal run: watch checks, reduce logs, fix-and-push loop on cheap tiers | exists (`/goal` delegation policy) |
| **Morning digest** | merged / stopped / red / checklist, plus factory occupancy per project (shelf count, shaped, sketched, spec-ready, In Review) | to build as an Argus job |
| **Weekly retro** | scheduled Sunday run of `/retro` so learning doesn't depend on remembering | to schedule |
| **Post-deploy canary** (web) | `/canary` after production deploys | exists, unused |

---

## 4. The week

Two fixed appointments every day: a **morning verify** (20–30 min) and **the daily hour**. The days below are defaults; the tank check overrides them.

| Day | Morning (20–30 min) | The daily hour | Night |
|---|---|---|---|
| Mon | Verify | **Map:** Bet (15 min / project) → Shape the week's bets | `/goal` |
| Tue | Verify | **Map:** Design session or Commit (`/caspian`), whichever the bets need | `/goal` |
| Wed | Verify | **Spec:** grill → `/ce-plan` → `/packets` | `/goal` |
| Thu | Verify | **Spec:** chunks, or finish a Commit that ran long | `/goal` |
| Fri | Verify | **Spec:** fill the tank for three nights (Fri, Sat, Sun) | `/goal` |
| Sat | Verify | optional: zoom-in on one existing cluster, or skip | `/goal` |
| Sun | Verify | **Learn** (20 min) → set next week's appetite → top up the tank | `/goal` |

**Rules of the hour.**
1. Open with the tank check. Tank low = spec, regardless of the day.
2. One hour means one hour. A Commit or design session that needs two gets two days, not an evening.
3. End by typing the night's `/goal` line, even if it is early. The hour is not done until tonight is queued.
4. Mapping days feed next week's tank, spec days feed this week's. Keep about two nights of buffer so a missed hour does not stall the line.

Any spare block is a **zoom-in** (above): one existing PRD or issue cluster. Freehand projects (§5) live outside this calendar on purpose. Blue-sky capture happens on any day, at any hour, and changes nothing about the week.

---

## 5. Which projects run the full line

| If the project… | Tier | What that means | Today |
|---|---|---|---|
| touches money, health guidance, migrations on real data, or someone else's data | **Full line** | every stage above; risk gates; release tags; smoke + full suites | motus · saidso · acquired-taste · **polybot (move here)** · **acquisition-stack (move here)** |
| has users besides you, or feeds something that does | **Line-lite** | Stages 0, 1, 5, 6, 7; Caspian and design sessions only at inflection points | argus · pulse · helm · search-os · atlas-os · sonar · cgsc · forge · topos |
| is play, craft, or exploration | **Freehand + floor** | vibe freely; one CI job if tests exist; work lands on `main`; learnings still captured | first-tack · experiments · dev-workflow |

Per-*issue* rigor stays with the flow labels regardless of tier: a `flow:ship` one-liner inside Motus ships plan-light; a schema change inside a freehand repo should still make you pause.

---

## 6. Build list — what to build, in order

| # | What | Stage it serves | Status |
|---|---|---|---|
| — | ~~`zmcray-plan` betting pass + skeleton test~~ | 1, 5 | **archived** (Sep 21) — betting is now the idea shelf read against `STRATEGY.md`; the skeleton test is applied during `/ce-plan` |
| — | `/packets` bridge: plan units → Linear chunks with packets, file scope, edges, `tier:*` | 5 | **done** (Sep 21), not yet run on a real plan |
| — | `caspian` delta D8: design-session gate, appetite-before-scope, Later Shelf | 3, 4 | **done** (Aug 7) |
| — | `/sketch` command | — | **removed** — the design session is a walk-through, not a skill |
| 1 | **Morning checklist emitter** (a rule in AGENTS.md > Session close): acceptance criteria per merged issue → Linear comment + digest | 7 | to build (small) |
| 2 | **Smoke / full gate split**: `Smoke.xctestplan` in motus + saidso; AGENTS.md encodes per-issue = smoke, train end = full; nightly full-suite workflow | 6 | to build (biggest time win) |
| 3 | **Runner sleep + health**: `caffeinate -s` in both runner launchd plists; a saved runner-health loop prompt / scheduled task | 6, loops | to build (30 min) |
| 4 | Goal runs pull only `spec-ready`; empty queue = stop with "plan first" | 5, 6 | **done** (Sep 21, AGENTS.md > Autonomous runs) |
| 5 | Shape-doc + sketch-summary **templates** into `dev-workflow/templates/` (from §7) | 2, 3 | to build (copy) |
| 6 | **Risk tripwire** CI job (reusable workflow deployed like AGENTS.md): risky paths without `flow:design` → fail | 6 | to build |
| 7 | **MCR-748** TestFlight from `main` + tag on cut | 6, 7 | in progress |
| 8 | Argus **factory digest** job (stage occupancy + overnight results) | 7, loops | later |
| 9 | `/zmcray-kickoff` acquisition-stack; polybot CI + paper-trading gate | 5 | to do |

---

## 7. Templates

### Shape doc — `docs/strategy/shapes/YYYY-MM-DD-<slug>.md`

```markdown
# Shape: <name>
Bet: <MCR-ID or buildnote>      Appetite: <one weekend / two nights / ...>

## Problem
<one paragraph: who, when, what hurts today>

## Loop sentence
[user does X] → [magic Y appears]

## Spine (top row = skeleton)
1. ...   2. ...   3. ...   4. ...   5. ...
Below the line: <steps that are real but not M1>

## Dominant risk
<value | usability | feasibility | viability> — retire by: <design session | spike | /hagen | council>

## Rabbit holes
- <where this could eat the appetite>

## No-gos (Later Shelf seeds)
- <explicitly not this time>

## Design session?  yes / no — <which rubric row fired>
```

### Sketch summary — `docs/strategy/sketches/YYYY-MM-DD-<slug>.md`

```markdown
# Sketch: <name>
Canvas: <Claude Design / Figma link>      Direction chosen: <name>      Verdict: keep / reshape / kill

## Loop sentence
...

## Screens (in loop order)
| # | Screen | Primary action | Secondary | Next | Data shown | Not here |
|---|---|---|---|---|---|---|

## States covered (core screen)
empty · loading · result · error · first-run

## Taps to aha: <n>      5-second test: <what they said>

## Walk-through notes (verbatim)
- ...

## Shelf (parked screens / actions)
- ...

## Open questions for Caspian
- ...
```

### Morning verification checklist (emitted by wrap; one block per merged issue)

```markdown
## MCR-### — <title>   build: <tag / preview URL>
- [ ] <acceptance criterion 1>
- [ ] <acceptance criterion 2>
- [ ] matches canvas: <screen names>
Result: done / residual: <MCR-###> / kick back: <reason>
```

### Overnight kickoff (the whole Stage 6 human contribution)

```
/goal <milestone name | MCR-123 MCR-124 | "the spec-ready queue">
```
