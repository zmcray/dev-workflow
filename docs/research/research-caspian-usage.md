# Caspian in practice — evidence report

**Scope.** Skill def `~/Developer/dev-workflow/commands/caspian.md` + shared brain `~/Documents/Work/40_OS/05_Skills/caspian/`. Evidence: Claude Code transcripts (`~/.claude/projects/**`), the Caspian session store (`40_OS/08_Memory/caspian-sessions/`), 6 PRDs across 4 repos, git log + Linear.

**Caveat on evidence quality.** The session store is the strong evidence (30 markdown session files, structured, phase-by-phase). Claude Code transcripts are the *weak* half: only ~9 sessions can be positively identified as Caspian runs, and several of those are long-lived multi-day sessions where Caspian was one segment among build work, so per-run wall clock is approximate. Many Caspian runs happened in Cowork, not CC, and left no transcript here. Friction quotes below are therefore sparse and I have not padded them.

## 5. Run counts (answering the stats question first, since the rest leans on it)

| Metric | Value |
|---|---|
| Total sessions in store (2026-04-29 → 2026-09-02) | **30** (27 completed, 2 active, 1 abandoned) |
| Sessions in the last 60 days (Jul 23 → Sep 21) | **13** |
| Modes across the 30 | NEW 6, EXPAND 12, REFRESH 9, backfill/other 3 |
| Products | saidso 8, motus 4, telos 4, atlas 3, search-os 2, acquired-taste, fathom, forge, topos, radar, spine, first-tack, portco-os |
| Identifiable CC runs | **9** |
| User turns per run (CC, clean runs) | 3, 4, 7, 8, 8, 9, 9, 11 → **median 8** |
| Wall clock, clean single-purpose runs | 0.71h, 0.77h, 1.02h, 1.96h, 2.10h, 4.08h → **median ~1.5h** |
| Stalled / abandoned | 2 active (portco-os idle since **Jul 5**, telos-governing since **Aug 19**), 1 abandoned |

Cadence is real and sustained: roughly one Caspian session every 4–5 days for five months.

## 1. What it does well

**It finishes.** 27 of 30 sessions reached "completed" with a PRD on disk and Linear issues filed. PRDs land in the right place (`docs/strategy/YYYY-MM-DD-<topic>-prd.md`) with frontmatter carrying `linear_project`, `linear_initiative`, `linear_issues`, and in motus's case `linear_milestones` too.

**Drift detection on EXPAND/REFRESH is the sharpest feature.** It repeatedly caught things the user would have missed. `2026-07-26-motus-recovery-expand.md`: "MCR-777 shipped a device-free breathing surface…; MCR-768 is now overlapping backlog scope and should not be treated as net-new recovery work." `2026-08-11-saidso-identity-admission-refresh.md` caught that "MCR-1241 exists In Progress outside the PRD" and folded it in. This is the part no other skill does.

**The compound loop is genuinely loaded, not decorative.** 23 learnings files exist and sessions demonstrably read them — the intent-saves session lists 18 carried learnings by name, and `ambition-overrides-minimal-recs` is cited as having been confirmed for the **3rd** time in the Aug 6 saidso session. That's the skill learning a real thing about its user.

**Red Team / Eng Review pass earns its slot.** Decision Logs in the acquired-taste and telos-recipes PRDs carry distinct dated `Red Team pass (cross-model, fresh context)` and `Eng Review pass (cross-model, repo ground truth)` entries whose findings visibly changed scope (Aug 6: "Cut: 10 MVP → post-Eng 11 with substrate split").

**When the conditions are right, output converts fast.** The Sep 2 telos-recipes PRD (MCR-1505…1523) was ~90% Done in Linear within 18 days — 14 Done, 1 In Review, 1 In Progress, 4 correctly parked as `deferred`.

## 2. Where it wastes time

**Validation interrogation is the recurring irritant.** In the Jul 12 workout session the user answered four validation probes in four minutes with clipped one-liners — "i save it on instagram and then there are too many to find anything and i never go back anyway", "i used to, and might start again" — then cut it off with "**confirm**". The Jul 24 saidso session logged the pattern explicitly: *"User closed the interrogation ('don't ask another validation question'). Logged as accepted risk."* A learnings file exists for this (`2026-07-24-founder-closes-interrogation.md`), yet the Aug 15 telos session ran the same probes again ("yes i have lost places…", "yes they go through lists of saves… it's slow and painful"). The learning is recorded but not acted on.

**Rendering bug at the press-release gate.** Motus, Jul 13, 11:49: *"i still can't see the press release"* — the artifact was never displayed before the lock prompt. The user said "lock it" one minute later, i.e. locked something he hadn't seen.

**Terse-lock signature everywhere.** Across runs, the user's approvals are "lock", "lcok", "lock it", "keep it all", "confirm", "run it". The deliberation is doing work, but the *gates* are not: the user is clicking through them, which means gate count is pure cost.

**Ambition override is priced in, three times over.** The council recommends minimal, the founder picks maximum, every time (`ambition-overrides-minimal-recs`, confirmed Jul 12 / Aug 6 / Jul 27 sessions). The scope-minimization argument is burned fuel.

**Dead sessions never cleaned up.** `active/2026-07-05-portco-os-new.md` has been "active" for 78 days.

## 3. Where output goes unused

Tracing PRD `linear_issues` against `git log --all` in each repo:

| PRD | Issues | Referenced in commits |
|---|---|---|
| saidso seamless-capture (Aug 6) | MCR-1171…1182 | **4 / 12** (1171, 1172, 1173, 1174) |
| telos intent-saves (Aug 15) | MCR-1279…1296 | **3 / 18** (1279, 1280, 1283) |
| acquired-taste sourcing (Jul 27) | MCR-881…895 | **9 / 15** |
| motus recovery (Jul 26) | MCR-854…870 | **9 / 17** |
| **Total** | **62** | **25 (40%)** |

The pattern is identical in all four: the first-milestone issues get built, then the tail dies. Confirmed in Linear for intent-saves — MCR-1284/1289 still Backlog and MCR-1291/1292/1295/1296 sit `deferred` five weeks on. Telos's board now carries a large permanent shelf (MCR-985, 986, 987, 989, 990, 991, 992, 1092, 1095, 1097, 1100, 1147, 1186, 1335 — all `deferred`+`prd-source`, all Backlog).

**Two delta-8 features are simply not implemented.** Zero of the six PRDs contains a `## Later Shelf` section — they all render `## Deferred Features` instead. Only one PRD of six (`telos-intent-saves`) mentions an **appetite** budget; the skill mandates stating M1's time budget before scoping, and in practice it doesn't. The "skeleton contract" test (a feature enters M1 only if the loop breaks without it) is nowhere stated in any PRD, which is consistent with the 10–13 feature M1s that show up instead of skeletons.

**Back-write (D5) silently failed on the most successful PRD.** `telos/docs/strategy/2026-09-02-telos-agent-native-recipes-prd.md` still reads `linear_initiative: null` and `linear_issues: []` despite MCR-1505…1523 existing and mostly being Done. It also uses a ```yaml fenced block instead of `---` frontmatter, so it isn't machine-readable at all.

**Sizes are large but not padded.** 2,400–4,700 words for theme PRDs; sections are specific, not boilerplate. Kill conditions are real behavior thresholds (saidso's 40% semantic-failure gate), though the Sep 2 PRD shows erosion: `## Kill Conditions (softened to review triggers, per founder decision)`. Acceptance criteria live in per-feature detail blocks and are mostly executable.

## 4. The highest-value changes

1. **Kill the validation interrogation after one probe when a learnings file says the founder closes it.** The skill already stores `founder-closes-interrogation`; make Phase 2 read it as a *behavioral override*, not a note. Cost today: 4–8 turns per NEW/EXPAND run.
2. **Implement the D8 skeleton contract for real.** State the M1 appetite out loud, then enforce "does the loop break without it" as a hard filter. 0/6 PRDs did this, and the 40% build-through rate is the consequence.
3. **Rename `Deferred Features` to `Later Shelf` and add kill conditions + a re-price date per item.** Deferred issues currently become permanent Linear sediment (14+ on telos alone) with no exit path.
4. **Fix the back-write step and make it verify.** After Phase 8, re-read the PRD and assert `linear_issues` is non-empty and frontmatter is `---`-delimited; fail loudly otherwise. The Sep 2 telos PRD proves this fails silently on the happy path.
5. **Render every artifact before its lock gate.** The motus "i still can't see the press release" case means a gate fired on an unseen artifact. Print, then ask.
6. **Collapse gates.** Six lock points against a user who answers "lock"/"confirm"/"lcok" — merge Phases 2–4 into a single "here's the frame, press-release, and council mode: lock or amend" checkpoint, and reserve real gates for scope cut (Phase 6) and ship (Phase 7→8).
7. **Stop arguing scope down; argue sequence.** The learnings store already concluded this (`sequencing-lands-where-cutting-doesnt`). Make Phase 5 default to sequencing alternatives rather than minimal/mid/max scope alternatives.
8. **Add a session-store janitor.** Anything `active` and untouched >14 days gets surfaced at the next Caspian kickoff for resume/abandon. Two sessions are stuck today, one for 78 days.

**Also worth noting, honestly:** the sharpest frustration quote in the transcripts — *"i'm so fucking confused. I have resend set up for acquired tast already"* (Jul 28, 16:36) — is from the **build** phase downstream of Caspian, not from Caspian itself. Caspian's own turns draw terse impatience, not anger.
