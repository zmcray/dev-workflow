# Agent-friendly codebase: make the right path the easy path

- **Created:** 2026-10-16
- **Tier:** not set (each unit is sized below; tier at /packets time)
- **Linear Project:** each repo's own project (see "Where the issues live"). The cross-repo project first used for this plan is canceled.
- **Linear Issues:** MCR-3302 to MCR-3317 (U1 to U16), split-offs MCR-3325 to MCR-3332, plus MCR-3300 (live bug the study found)
- **Task:** Find the mistakes agents keep repeating in the 10 active repos and remove them through code: architecture and types first, shared CI guards next, prose last. Back every proposal with real data, and settle open questions by prototype.

**Privacy note:** this repo is public. The plan holds only counts, commit shas and file names. The raw evidence (Zack's quotes, Slack items, per-fix JSON, prototype outputs) lives in `.local/agent-pitfalls-2026-10-16/`, which is git-ignored.

## Why now

- **Agents write almost everything.** The 10 repos had about 2,120 commits in 90 days, and 91–99% carry an agent co-author trailer.
- **No human review exists to catch mistakes.**
  - On GitHub, Zack wrote 0 PR reviews and 0 critique comments. All 43 bodies under his account are agent output.
  - His steering happens in agent chats: 369 corrections in 1,909 typed messages (19.3 per 100).
- **Fixes are a quarter of the work.** 490 of about 2,120 commits are fixes (23%).
- **Prose is not holding.**
  - Rules re-edited 3–11 times and broken anyway: date-last names, docs-PR IDs, never work on main, "Dose is the single value", the redefine hazard.
  - MCR-2719 (Stop hook in 4 repos) is marked Done, but only telos has one. The shared `hooks/stop-fast-check.sh` added on 2026-10-16 isn't called by any repo yet.

## How the study worked

- **Sources:**
  - Zack's typed messages from Claude Code, Codex and Cursor transcripts (1,909).
  - Fix, revert and follow-up commits in all 10 repos, with diffs read (490).
  - GitHub, Slack and Linear feedback (13 items; null results noted).
- **Method:** pstack `/correct` and `/architect`. A class counts once it happens twice. Each fix is placed at the highest level that works.
- **Backtest:** classes were built only from fixes on or before 2026-09-04. Fixes from 2026-09-05 on were then checked against them.
  - Code repos: 256 test fixes, 186 in a known class, 94 judged plausibly blocked by the proposed guard (37%).
  - That number is the proposing agents' judgment, so the prototypes below measure the top guards against real commits.
- **Known gaps:**
  - The train window is thin for pulse, quoting, pulse-ios and dev-workflow (repos or transcripts start in late September).
  - Linear can't tell Zack's comments from agent comments, because both post as him.

## The pitfall map

| Theme | Fix commits | Corrections | Where it bites | Highest level that works |
|---|---|---|---|---|
| One owner per fact (duplicate truth, stale copies, config drift, schema drift) | 118 | 41 | motus, telos, argus, sonar, pulse, quoting, skills | Architecture |
| State and outcomes not modeled (scattered state, failures that read as success, swallowed errors) | 107 | 7 | motus, pulse, argus, sonar, saidso | Types + architecture |
| Verification that doesn't prove the real thing (unverified done, CI that proves nothing, flaky e2e) | about 100 | 41 | telos, motus, saidso | Verification skills + merge gates |
| Unparsed boundaries and type escape hatches | 52 | 2 | telos, pulse, motus | Types (parse at boundary, required shapes) |
| Agent–human interface (hands work back, broken human steps, false "tool unavailable", unclear asks) | 0 | about 115 | every repo | Subtract the cause, then tested wizards |
| Intent and UI (wrong intent, polish, over-engineering, scope creep) | 52 | about 80 | every repo | Judgment: fresher PRDs and design gates, not code |

## What the prototypes settled

All prototypes are throwaway. Each was run against real past commits, and the code and results are in `.local/agent-pitfalls-2026-10-16/prototypes/`.

| Question | Result | Decision |
|---|---|---|
| Can CI catch telos's redefine hazard? | "Delta" check: 9/9 true positives, 2/72 false positives, 0.2s. Naive diff variants: 34–52/72 false positives. It also found a live bug (MCR-3300). | Ship (U7) |
| Does a Swift ratchet catch swallowed errors? | Flagged the exact buggy line in 7/9 fixes. Noise 6/108 recent commits. | Ship shared (U4) |
| Ban force unwraps or optional fields in Swift? | 0/13 and 1/13 caught | Don't ship. The fix is a type (U9) |
| Owner-table check for duplicate truth in Swift? | 8/26 exact line, but out of sample 2/14 | Backstop only. Module boundaries are the fix (U9) |
| Pin Pulse tests to Pacific/Auckland? | Caught 0/4 real clock bugs | Don't ship. Use an injected `now` and a frozen Date (U10) |
| Ban ambient `Date` in Pulse? | 40–48% of normal commits flagged, two thirds benign | Don't ship (U10) |
| Store-boundary lint in Pulse? | 8/13 bad commits flagged, 2/13 at the culprit line | Ship only after the store exists (U10) |
| Date-last filename check? | Catches both known violations. 299 commits added date-first files, mostly from generators | Fix the generators, then ratchet (U2) |
| Can a phrase check spot agents handing work back? | Recall 0–1/73 | No. The signal is the "Action needed" slot (U1) |
| Move Pulse to TypeScript? | quoting already runs strict TS with the same classes and a 19% fix rate. 1 Pulse fix was a type error | Don't (U10) |

## Sequencing decision (2026-10-16)

Only part of this plan rests on measurement. The rest rests on agent judgment, and the prototypes showed that judgment runs high: where a prototype tested an idea, the result usually came in lower than the agents' estimate, and 4 proposed rules were dropped. A big rebuild produced by the same agents would also bring its own share of fix commits. So the work is split into two Linear milestones:

- **Now: proven fixes (target 2026-10-30).**
  - MCR-3300 first, then U7, U5, U6, U1, U2, U4 and U16.
  - U4 ships only the date-last and Swift swallowed-error rules.
  - U16 is included because its 2-week rerun is the gate for everything else.
- **Later: decide after rerun (target 2026-11-13).**
  - U3 and U8 to U15.
  - Nothing starts until the rerun reports.
  - Then pick one large unit (U9, U10 or U11), build it, and check whether its class stops recurring before starting the rest.

## Where the issues live

Your Linear rules give each repo one project, and `/factory` only drains the repo's own project. So each issue sits in the project of the repo where its code lands. "Now" issues sit in a live hardening milestone. "Later" issues sit on a shelf with Low priority and `deferred`, so the factory skips them until the rerun.

| Unit | Issue | Project | Milestone |
|---|---|---|---|
| Telos purge bug | MCR-3300 | telos | Platform: hardening |
| U1 output style | MCR-3302 | Workflow | Factory: hardening |
| U2 date-last templates and guard | MCR-3303 | Workflow | Factory: hardening (merged, #43) |
| U4 shared guards | MCR-3305 | Workflow | Factory: hardening (workflow merged, #44; per-repo wiring open) |
| U5 branch protection | MCR-3306 | Workflow | Factory: hardening (audit merged, #45; apply waits for Zack) |
| U6 Stop hook wiring | MCR-3307 | Workflow | Factory: hardening |
| U7 redefine-hazard check | MCR-3308 | telos | Platform: hardening |
| U16 rerun script | MCR-3317 | Workflow | Factory: hardening |
| U3 skill manifests | MCR-3304 | Workflow | Factory: later |
| U3a argus one deploy path | MCR-3325 | Argus | Later: deferred |
| U3b sonar one lockfile | MCR-3326 | Sonar | Later: deferred |
| U3c saidso Xcode Cloud only | MCR-3327 | Saidso | Later: deferred |
| U8 telos registries as rows | MCR-3309 | telos | Later: deferred |
| U9 motus ItemShape and owners | MCR-3310 | Motus | Platform: later |
| U10 pulse store and clock | MCR-3311 | Pulse | Platform: later |
| U11a argus job outcomes | MCR-3312 | Argus | Later: deferred |
| U11b sonar runVerb | MCR-3328 | Sonar | Later: deferred |
| U11c pulse tagged fetch results | MCR-3329 | Pulse | Platform: later |
| U11d saidso failure disposition | MCR-3330 | Saidso | Later: deferred |
| U12 shared schema owners | MCR-3313 | Workflow | Factory: later |
| U13a verify-motus | MCR-3314 | Motus | Platform: later |
| U13b verify-saidso | MCR-3331 | Saidso | Later: deferred |
| U13c verify-pulse | MCR-3332 | Pulse | Platform: later |
| U14 tested wizards and closeout | MCR-3315 | Workflow | Factory: later |
| U15 rule table | MCR-3316 | Workflow | Factory: later |

## Units

Order: subtract first, then shared guards, then architecture per stack, then verification, then prose. Units in the same phase touch different repos, so they can run in parallel.

### Phase 0: Subtract (S each)

- **U1 (MCR-3302): Stop the output style from inviting hand-backs.**
  - "Action needed" appears in 0 of 594 agent replies in Jul–Aug and 439 of 1,301 in Sep–Oct. The exec-brief style that requires it was created 2026-09-03.
  - Hand-back complaints went from 1.18 to 2.38 per 100 messages while all corrections stayed flat.
  - Inferred, not proven: it is confounded with the factory era starting.
  - Version the style in dev-workflow and rewrite the slot so it holds only real human gates. Re-measure for 2 weeks.
- **U2 (MCR-3303): Fix the date-first generators, then ratchet.**
  - The source is ce-plan, factory runs, checkpoints, research sources and design briefs.
  - Delete the prose override note MCR-2721 added; it failed the next day (18e8ae9).
- **U3 (MCR-3304): Delete second paths agents copy.**
  - argus `sync-skills.sh`, sonar's stale lockfile, and saidso's local build-number script, which fights Xcode Cloud.
  - Generate the skill manifests from one list, which today is hand-kept in 4 places.
- **U16 (MCR-3317): Make this study a monthly measurement.** The baseline table is in the issue.

### Phase 1: Shared guards in dev-workflow (M each)

- **U4 (MCR-3305): `guards.yml` plus pre-commit, called by all 10 repos.**
  - Today no repo calls dev-workflow, and dev-workflow and mcray-os-skills have no CI.
  - First rules: date-last names, docs-PR IDs, AGENTS block md5, the retired-names list, and the Swift swallowed-error ratchet.
  - All rules are ratchets with fix-naming errors.
- **U5 (MCR-3306): Merge gates as code.**
  - Only 2 of 8 protected repos require PRs to be up to date. There are no merge queues, and 6 repos allow direct pushes to main.
  - A script audits and applies strict up-to-date, enforce on admins, and a required PR.
  - Correction found while building it: argus's second suite (relay-ci) runs only on some paths, so it can't be required directly. argus needs an always-run gate job first.
- **U6 (MCR-3307): Finish MCR-2719.**
  - Install the Stop and PreToolUse hooks machine-wide, and fail closed.
  - An audit proves each repo's hook blocks a red turn.

### Phase 2: Architecture per stack (L unless noted)

- **U7 (MCR-3308, M): Telos redefine-hazard CI check.** Use the prototype's delta design and run it against current main. Needs U5.
- **U8 (MCR-3309): Telos registries as rows, and one object-version writer.** Every real hazard case was a registry function.
- **U9 (MCR-3310): Motus.**
  - A required `ItemShape` type through one converting init.
  - One owner each for `SelectableCatalog`, weekStatus and `ExerciseLookup`, with fetches internal to `MotusKitPersistence`.
- **U10 (MCR-3311): Pulse.**
  - A `src/data/store.js` that owns optimistic writes, rollback, latest-wins and invalidation.
  - Functions take `now` as a parameter, and tests freeze Date.
- **U11 (MCR-3312): Typed run outcomes.** One status enum per job, so "OK … 1 failed" can't happen. Covers argus, sonar, pulse and saidso.
- **U12 (MCR-3313, M): Shared Supabase schema.** A table-owner map enforced in CI, and nightly RPC proofs against a prod schema-only dump.

### Phase 3: Verification and human steps (M each)

- **U13 (MCR-3314): Verification skills for motus, saidso and pulse.**
  - Built with `/create-verification-skill`.
  - iOS device-only APIs need device evidence.
  - The factory's done gate reads the evidence file.
- **U14 (MCR-3315): Human steps and close-out as code.**
  - Human steps become wizards that run a `doctor` on this machine first.
  - A `closeout` command replaces the sequence Zack typed about 55 times.
  - A connector doctor runs before any "tool unavailable" claim.

### Phase 4: Prose last (S)

- **U15 (MCR-3316): Rule table in the AGENTS block.**
  - Each rule names its enforcer.
  - Rules whose mistake is now impossible get deleted.
  - Unenforced rules become Linear debt.
  - Wrong intent, polish and scope stay as judgment.

## Not doing

- **TypeScript migration for Pulse.** See the prototype table.
- **TLA+ or formal verification.** No hotspot needs it. The concurrency bugs found are stale async results in UI code, which U10 and U9's ownership fixes address.
- **Mass-renaming date-first history.** The ratchet blocks new names, and history stays.
- **A lint for wrong intent or UI polish.** No signal separates them. They stay with PRDs, design gates and verification skills.

## Success measure

Rerun the study monthly (U16). Targets for 2026-12-16:

- Fix-commit share under 15% (now 23%).
- Corrections under 12 per 100 messages (now 19.3).
- Hand-back complaints under 1 per 100 (now 2.38).
- Every AGENTS rule has an enforcer or is marked judgment.
