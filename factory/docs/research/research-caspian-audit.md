# Caspian Design Audit

Audited 2026-09-21 against the Compound-Engineering-native toolchain (`/ce-plan` → `/packets` → `/goal`).

---

## 1. Instruction budget

**What loads.** `~/Developer/dev-workflow/commands/caspian.md` ("Read the shared brain first (do not skip)") mandates ten files before the session starts. Measured word counts:

| File | Words |
|---|---|
| commands/caspian.md (wrapper) | 1,950 |
| SKILL.md | 3,288 |
| phases.md | 4,533 |
| gotchas.md | 2,945 |
| deliberation.md | 2,852 |
| council.md | 2,307 |
| linear-write.md | 2,259 |
| governance.md | 2,034 |
| prd-template.md | 2,031 |
| modes.md | 1,499 |
| voice.md (read "if the voice drifts") | 1,770 |
| compound.md (loaded at Phase 1/9) | 972 |
| **Subtotal (skill tree)** | **~28,440** |

Plus three Work-folder context files (`about-me.md`, `McRayGroup.md`, `voice-and-style.md`) not counted here. Realistic cold-start load: **~30–35k words ≈ 40–47k tokens before the first question is asked**, in a session whose main-thread context is also carrying the Linear MCP, the repo, and the conversation itself. That is the single largest design defect: the anti-sycophancy rules and the lint (the parts that actually change output) sit at the far end of a 40k-token preamble and degrade exactly where `gotchas.md` says they degrade ("persona judgment degrades over a long session").

**Duplication.** The same content is stated three or four times:

- Anti-sycophancy: `deliberation.md` §Anti-Sycophancy (6 rules), `council.md` §Anti-Sycophancy (3 rules), `voice.md` §Anti-Sycophancy, SKILL.md Anti-Patterns. Four copies, non-identical.
- Refresh tier logic: identical pseudocode block in `governance.md` §Tier Classification and `modes.md` §Refresh Tier Classification. Verbatim duplicate.
- Phase 8 nine steps: listed in SKILL.md §Linear Write Step, again in `phases.md` Phase 8, again in full in `linear-write.md`.
- Signature questions: `voice.md` §Signature Questions, `council.md` per-voice, SKILL.md §Voice.
- Phase voice-attribution table: SKILL.md and `voice.md`.
- No-delete/never-roll-back: SKILL.md, `governance.md` §1 and §Failure Handling, `linear-write.md` header and §Failure Recovery, wrapper D2.
- Lazy kickoff: SKILL.md, `phases.md` Phase 1, `modes.md` NEW, `linear-write.md` Step 4, `gotchas.md`, wrapper D3. Six copies.

Conservatively **6–8k words are pure restatement**.

**Dead or contradictory.**

- `/zmcray-build` is retired but still referenced: `linear-write.md` Step 6 ("to be defined during `/zmcray:build`"), Plan Notes "reserved for `/zmcray:wrap`", `governance.md` §1 enforcement table (rows for `/zmcray:wrap`, `/zmcray:build`) and §Divergence B, wrapper D2 ("This is what routes `/zmcray-build`"). Per MANUAL §Intro these are now AGENTS.md rules; the build loop is `/goal` → `/lfg`.
- Notion Project Registry is load-bearing in `linear-write.md` Step 8 (**halts** if the entry is missing) and in `governance.md` §Project Registry, but the wrapper D4 demotes it to "portfolio bookkeeping, don't block". The halt rule is live text that contradicts the wrapper.
- Cowork-vs-Claude-Code forks run through every file: GraphQL/`MANUAL-PENDING` fallback (`linear-write.md` Step 3) is explicitly dead in CC per D2; `~/.linear-projects.json` cache (Step 4) contradicts AGENTS.md's "`.linear-project.json` at the repo root — the link travels with the repo, no central cache"; `computer://` links are a Cowork artifact appearing in Step 6 issue bodies, Step 7, Step 8 and the close pattern.
- `mvp:m1` / `mvp:m2` labels are mandated in `linear-write.md` Step 6 and **explicitly banned** by wrapper D2 and AGENTS.md ("never invent labels that mirror milestones (`mvp:c1`)"). A live contradiction inside the instruction set.
- SKILL.md frontmatter still advertises "Notion Project Registry update" as output; SKILL.md §Phase Flow omits the Later Shelf entirely, which D8 says must be in the rendered PRD.
- `references/council.md` §Voices Considered and Excluded (~500 words) is design rationale, never used at runtime.
- `gotchas.md` is 2,945 words of which the majority restate rules already in `phases.md`/`deliberation.md` (premise challenge, forcing questions, alternatives, Red Team, what-we-lose). Only ~8 entries are true field-observed incidents with dates.

**What should be a pointer.** `linear-write.md` (2,259 w) is a mechanical runbook needed only at Phase 8 — load it there, not at start. `prd-template.md` is needed at Phase 7. `governance.md` §Divergence Handling describes build-loop behavior owned by AGENTS.md — delete and link. `council.md` Layer 1 (voices, ~1,400 w) is mostly biography; the operative content is the phase→framework mapping plus signature questions, ~300 words.

---

## 2. The phase arc

Estimated wall-clock for a typical feature-sized EXPAND run (matches MANUAL Stage 4's ~2h budget):

| Phase | Est. | Who decides | Verdict |
|---|---|---|---|
| 0.5 Intake | 0–10 | human | Earns it on fog; correctly gated by the one-breath test |
| 1 Set Up | 8–12 | human (mode/scope/drift), skill (retrieval) | Half earns it (drift). Mode/scope AskUserQuestion is usually one-tap ceremony |
| 2 Frame | 15–25 | human | **Highest value.** Premise challenge + forcing questions are where builds die cheaply |
| 3 Imagine | 8–12 | skill drafts, human locks | Earns it; the 150-word cap is real discipline |
| 4 Calibrate | 3–5 | human | **Ceremony.** A four-option AskUserQuestion that only modulates Phase 6 attitude. Mergeable into Phase 6's opening line |
| 5 Build Feature Set | 25–40 | human locks approach, skill generates | Earns it (alternatives + four-risks). Deepen adds 10–20 when run |
| 6 Cut | 20–35 | human per feature | Earns it, but per-feature AskUserQuestion is the slowest step; 12 features = 12 gates |
| 6.5 Red Team | 8–15 | human adjudicates | Earns it — the single highest-leverage pass |
| 6.75 Eng Review | 8–15 | human adjudicates | Earns it *now*, but see §6: `/ce-plan` re-does this downstream |
| 7 Render + lint | 8–12 | skill (lint), human (overrides) | Lint earns it; render is mechanical |
| 8 Ship | 10–20 | human (one confirm) | Mechanical; Notion + registry steps are dead weight |
| 9 Compound | 5–10 | human adjudicates | Earns it if the store is actually retrieved |
| **Total** | **~2h–3h20** | | |

Against MANUAL's "~2 h, may span two daily hours" this overruns. The overrun is concentrated in gate count, not thinking: a single run fires roughly **20–35 AskUserQuestion prompts** (mode, scope, product, drift×N, type, problem lock, press release, council mode, approach, feature×N, MVP-cap, milestones, Red Team×N, Eng×N, Heavy ack, lint overrides, ship confirm, learnings). Nothing in the skill batches or budgets them.

Asymmetry worth naming: the skill **decides** almost nothing autonomously (only refresh tier and lint pass/fail). Every judgment is bounced to the human. That is defensible for kills and scope, wasteful for `flow:*` classification, milestone grouping, and V/U/F/V drafting.

---

## 3. The council mechanism

**Five voices: partly theater.** `council.md` itself concedes the point — "A council of five personas who all reason the same way is theater. The lenses are what stop that." But the design then binds one voice per phase (Phase 2 = PG, 3 = Bezos, 4 = Tan, 5 = Cagan, 6 = Jobs). That is not a council deliberating; it is **five sequential single-expert phases with a costume**. No phase ever puts two voices in tension with each other. The only cross-voice check described (`council.md` §How the Council Works Together: "PG keeps Bezos honest…") has no mechanism behind it — it is prose, not a procedure. What actually produces value is structural, not personal: press-release-first (Bezos), the four-risks grid (Cagan), forcing questions with red flags (PG), the 10-cap (Jobs). Those survive without the names.

**Five lenses: real, but under-specified.** Only three are mandated (`phases.md` 5.1: inversion, first principles, naive outsider). Analogy and dependency-graphing are optional — yet dependency-graphing is precisely what Phase 6.75 later outsources to a subagent. The lens layer is the genuinely differentiated part and it is the part with the weakest enforcement: no lint item checks that a lens was run (L1–L12 never mention lenses).

**Where anti-sycophancy actually bites.** Three places have teeth because they have a mechanism: (a) theatrical-consensus detection → run an unused lens (`deliberation.md` §1); (b) "what we lose" on every Defer/Kill, enforced by lint L7; (c) "killing the build is a legal outcome," with Phase 9 required on premise kills. The rest — "no flattery," "quote the words" — are style rules with no verification step, and style rules without a checker are the first thing to drift at 40k tokens.

**Red Team independence: structurally real, operationally fragile.** It is genuinely fresh-context (transcript withheld, only locked artifacts handed over — `deliberation.md` §4), and CC prefers a *different model* via Codex (wrapper D6). That is real independence, better than most "adversarial pass" designs. Three weaknesses: (1) the brief hands over the locked scope *and* the rejected alternatives, which anchors the reviewer on the council's framing of its own options; (2) `gotchas.md` records the Codex placeholder failure — the pass can silently no-op; (3) Eng Review sees ground truth but `gotchas.md` records it reading a stale checkout. Both reviewers' findings are adjudicated by the same human who just spent two hours building attachment, with no forcing function to accept any. Independence of *input* is solved; independence of *judgment* is not.

---

## 4. Outputs vs. what downstream needs

The PRD template predates the factory and shows it.

**Present and right-sized:** explicit non-goals (§8 Out of Scope, REQUIRED), Tradeoffs/dissent (§8b), Killed graveyard (§12), Kill Conditions (§7), Decision Log (§15).

**Missing — what `/ce-plan` and `/packets` actually need:**

1. **Executable acceptance criteria.** `build-packet.md` requires EARS-form criteria each naming a test or screenshot check. The PRD template's Feature Details (§10) has description + four risks and *no* acceptance criteria; `linear-write.md` Step 6 emits the literal placeholder "to be defined during /zmcray:build". So every issue Caspian creates starts non-`spec-ready` and the criteria get invented downstream by an agent that has less context than the council did. **This is the biggest output gap.**
2. **Later Shelf.** Mandated by wrapper D8 ("include this section even if the shared template lacks it") — and the shared template lacks it. MANUAL Stage 4's exit gate *is* "M1 = skeleton only, everything else on the shelf with a kill condition." The template has "Deferred Features" with no kill conditions.
3. **Skeleton M1 / loop sentence.** MANUAL Stage 2 makes the loop sentence the spine of everything; D8 makes the skeleton contract a gate. Neither appears in the template. §13 Milestones is a feature grouping, not a walking skeleton.
4. **Appetite.** D8 requires stating the M1 time budget before scoping. Nothing records it.
5. **File-scope / blast-radius hints.** `/packets` must infer file scope and blocking edges from the plan. The PRD's Dependencies section (§9) is prose buckets, not a graph — yet Phase 6.75 produced exactly the dependency chain `/packets` needs and the template discards its structure.
6. **`flow:*` rationale.** The label is stamped at Phase 8 with no PRD record of why.
7. **Research decision.** AGENTS.md requires `reuse | extend | none needed` with claim IDs in every design/standard plan; the PRD's References (§16) is an unstructured bibliography.

**What nobody reads:** the Notion Project Registry fields; `computer://` links (broken in CC); `project_registry:` frontmatter; §3 Mode as a standalone section (council mode never routes anything downstream); the per-issue Cagan block in Step 6 (four prose lines a building agent cannot act on — value/viability are strategy, already decided).

---

## 5. Modes

**NEW vs EXPAND vs REFRESH are distinguishable on paper and blurry in practice.** The real distinctions reduce to three binary switches: *is there a prior PRD* (drift detection on/off), *new file or in-place* (render), *create or update issues* (Step 6). Everything else in `modes.md` is restatement. Two live ambiguities:

- **EXPAND vs REFRESH** collapses whenever a theme is added *and* the existing M1 is re-sliced — MANUAL's "PRD zoom" row calls that REFRESH, `modes.md` calls adding a theme EXPAND. The skill's own tell: `modes.md` flags REFRESH+Expansion as "usually EXPAND."
- **EXPAND's initiative question** is answered opposite ways in the same toolchain: `modes.md`/`linear-write.md` Step 3 say "usually create a new Initiative"; wrapper D2 and AGENTS.md say **one initiative per product, ever** — a theme becomes a milestone group. EXPAND as a distinct mode barely survives that ruling; it is REFRESH with a new milestone group.

**Missing lightweight mode.** Yes, and the factory names the need: MANUAL's "Feature zoom" and "Issue zoom" rows, plus Stage 0's "riff for an hour → stop at the PRD doc." A one-feature commit on an existing product with a sketch in hand does not need Phases 3, 4, 6.75 or a 12-check lint. Propose **PACKET mode** (or SLICE): Phase 2 premise + forcing questions (short), skeleton contract, cut, Red Team, ship issues into an existing milestone. ~30 minutes, no press release, no council-mode gate, one confirm. That is the mode that would actually get used on a Tuesday.

---

## 6. Top 10 changes, ranked by impact / effort

1. **Put executable acceptance criteria in the PRD and the issue.** Add an `Acceptance criteria` block (EARS form, each naming a test or screenshot check) to Feature Details in `templates/prd-template.md`, and replace the "to be defined during /zmcray:build" placeholder in `instructions/linear-write.md` Step 6. Caspian holds the context to write them; every hour saved downstream in `/ce-plan` compounds across every issue. *Highest impact, ~1 hour.*
2. **Split the load: start-time vs. phase-time.** Cut the wrapper's ten-file preamble to four (`council.md` trimmed, `deliberation.md`, `phases.md`, `modes.md`) and load `linear-write.md` at Phase 8, `prd-template.md` at Phase 7, `governance.md` at the first gate. Touches `~/Developer/dev-workflow/commands/caspian.md` §Read the shared brain. Halves the cold-start burn and puts the lint nearer the top of context.
3. **Add PACKET mode.** A fourth mode in `instructions/modes.md` (+ a routing line in SKILL.md and the wrapper): one feature, existing PRD, skip Phases 3/4/6.75, one Red Team, ship into an existing milestone. ~30 minutes. This is the mode that matches MANUAL's feature-zoom and spec-day cadence.
4. **Fold the Later Shelf, loop sentence, appetite and skeleton contract into the template.** `templates/prd-template.md` gains `## Loop sentence`, `## Appetite`, `## Later Shelf` (defer rationale + kill condition per item). Today these live only in wrapper D8, which tells the render to invent a section the template lacks — a guaranteed drift point.
5. **Purge the retired toolchain.** Remove `/zmcray:build`, `/zmcray:wrap`, `mvp:m*` labels, the GraphQL/`MANUAL-PENDING` fallback, `~/.linear-projects.json`, and `computer://` links from `instructions/linear-write.md` and `instructions/governance.md`; demote the Notion halt in Step 8 to a warning. Removes a live label contradiction with AGENTS.md and ~1,500 dead words.
6. **De-duplicate anti-sycophancy and refresh tiers to one home each.** Keep anti-sycophancy in `deliberation.md` and refresh tiers in `governance.md`; replace the copies in `council.md`, `voice.md`, `modes.md` and SKILL.md with one-line pointers. ~4k words recovered, no behavior lost.
7. **Make the lens pass verifiable.** Add a lint item (`phases.md` Phase 7 table) — "≥2 lenses named and run in Phase 5, with what each surfaced" — and record them in the Decision Log. Lenses are the council's only genuine cognitive diversity and are currently the only major mechanic with zero enforcement.
8. **Budget the gates.** In `instructions/phases.md` Phase 6, batch undisputed features into one multiSelect and reserve per-item gates for Defer/Kill and anything the skill flags; same for Red Team/Eng findings the user is not acting on. Cuts 20–35 prompts to roughly 10 and brings the run inside MANUAL's 2-hour Stage 4 box.
9. **Emit a dependency graph, not prose.** Change `templates/prd-template.md` §9 to a `A → B → (C, D parallel)` order line plus a per-feature blast-radius/`flow:*` call, sourced from the Phase 6.75 findings. `/packets` needs edges and file scope; today it re-derives what Eng Review already computed.
10. **Harden the reviewer contract.** In `instructions/deliberation.md` §4/§4b: require the Red Team brief to withhold the council's *recommendation* among the alternatives, require a ref-pinned ground truth for the Eng reviewer (`origin/main`), and make "result contains numbered findings" a precondition before adjudication. Both failure modes are already recorded in `gotchas.md` as field incidents; encode them as rules rather than warnings.

**Deferred (lower ratio):** merge Phase 4 into Phase 6's opening (saves 5 minutes, loses an explicit record); consider retiring Phase 6.75 once `/ce-plan`'s persona council is trusted — today it earns its slot because it is the only pass that sees Linear ground truth before issues exist.
