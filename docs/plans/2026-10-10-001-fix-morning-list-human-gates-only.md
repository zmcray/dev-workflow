---
title: "fix: Morning list holds only human gates, never QA/UI checks"
type: fix
date: 2026-10-10
---

# fix: Morning list holds only human gates, never QA/UI checks

- **Created:** 2026-10-10
- **Tier:** tier:moderate (prose contract edits plus one helper guard; each unit sized below)
- **Linear Project:** Workflow
- **Linear Issue:** MCR-2748
- **Task:** The factory floods Pulse's Build tab with small QA/UI checks. Only true human gates should reach Zack: secrets and credentials, product-direction calls, and blockers that stop work.

---

## Summary

The night shift stops filing `check` asks. It stops gating chunks on "a person must look at the screen". It resolves any open check it finds. What reaches Pulse is only `human_step` and `follow_up` asks. UI correctness is trusted to CI plus Zack's daily use of the apps. Each run leaves a plain record of what shipped without a visual check, and that record is never an ask.

---

## Problem Frame

Two rules feed the noise:

1. **Close of shift.** `commands/factory.md` Step 5 builds the Morning review from every merged issue's acceptance criteria. It keeps "UI or layout" and anything "not screenshotted", then files one `check` ask per item. Each check stays in Pulse for up to 14 days.
2. **Spec time.** `commands/packets.md`, `factory/templates/build-packet.md` and `rules/chunks.md` list "a person judging images or screens" as a `gate:human` trigger (`judgment:`). That turns visual QA into `human_step` asks. It also keeps those chunks out of the night queue.

The evidence says the checks don't work as a control. The 2026-10-09 hardening plan counted 106 uncleared checklist items. Ledgers record 0 failures out of 229 chunks. Nobody clears the checks, so they cost attention without working as a control. Whether they would catch regressions is unknown.

---

## Requirements

- R1. No `check` asks are filed by any factory run.
- R2. Pulse's Build tab shows only asks Zack must act on for work to keep moving: credential/vendor procedures, product-direction decisions, blockers (red baseline, blocked dependency, a parked gate).
- R3. "Does it look right" is not a `gate:human` trigger at spec time. A taste or naming call that changes what gets built still is.
- R4. Each run records what shipped without a visual check, in the status update and ledger, as information only.
- R5. Existing open checks are cleared. Any open check that is really a product question is re-filed as a `decide-scope` follow-up first.
- R6. Pulse's morning review panel keeps parsing the status update without a Pulse code change.

---

## Key Technical Decisions

- **Drop UI checks rather than have the agent verify them.** Night-time simulator runs are flaky: sim boot, disk, leftover state, coordinate taps. The bigger risk is false passes, because an agent judging its own screenshot almost always says yes. Zack's daily use of the apps is the better UI test. Rare screens (error states, onboarding, settings) go unverified until hit. That is an accepted trade-off.
- **Fix the rules, not Pulse.** If checks are never filed, Pulse has nothing to filter. The `check` kind stays in the `os.factory_asks` schema, so no migration or Pulse PR is needed and old rows stay readable.
- **The guard lives in this repo.** Two guards, both in dev-workflow:
  - The `factory-asks` helper refuses `upsert` for `kind: check`.
  - Every run's Step 1b resolves any open check it finds.
  
  Together they replace a Pulse-side filter and self-clean each project on its next run.
- **The Morning review section keeps its heading and contract, with new contents.** Pulse's parser (`api/_factory.js` in zmcray/Pulse) reads `- [ ] MCR-… <title>: <text>` lines under `## Morning review`, or the all-clear phrase "nothing needs your eyes". From now on that section lists only follow-ups **first filed tonight**: inserted, or queued unsynced and not already open at Step 1b. Human steps stay out of it. They already reach Pulse through the `Human batch:` line and the panel's gate:human "Needs you" list. Listing them here too would double them in the unsynced fallback view (`MorningReview.jsx` merges these lines without dedupe).
- **The "shipped without a visual check" record sits outside that section.** It is a plain line above `## Morning review`, never checkbox lines. That way Pulse's parser never turns it into review items. It covers only how a screen looks or behaves. A live-schema or prod read the builder could not run is not visual. It keeps the existing "Not an ask" path: the factory redoes the read, or files an `other-<slug>` follow-up for the part only Zack can do.
- **A refused check is dropped, never re-filed under another kind.** That covers a new check refused with exit 1 and a queued check replayed from `asks_pending`. Either way it gets a one-line ledger note. This stops the retired items coming back as `other-<slug>` follow-ups.
- **Testable criteria move into tests at spec time, as a soft rule.** `/packets` says that a criterion a test could prove (a snapshot or UI test) should name that test in the packet. A criterion only an eye can judge is accepted as unverified. It is not gated.

---

## Implementation Units

### U1. Factory contract: no checks, human-only Morning review

**Goal:** Step 5 and the Asks section stop producing checks, and the Morning review carries only human items.

**Requirements:** R1, R2, R4, R6

**Dependencies:** none

**Files:** `commands/factory.md`

**Approach:**
- Step 5 item 2:
  - Replace the "keep only what CI cannot prove" list. A visual or layout criterion not asserted by a merged test goes into a one-line `Not eyeballed: MCR-…, MCR-…` record (omit at zero). It is placed in the status update header block, above `## Morning review`.
  - A live-schema or prod read the builder could not run (or anything else noted "not run") follows the "Not an ask" rule: redo it, or file an `other-<slug>` follow-up for the part only Zack can do.
  - The ledger gets a matching `not_eyeballed: [{ issue, criterion }]` list.
  - A criterion that hides a product question becomes a `decide-scope` follow-up. This uses the existing "Not an ask" rule.
- Step 5 item 2, the Morning review section:
  - It lists one checkbox line per follow-up first filed tonight, in the existing line shape. Human steps stay on the `Human batch:` line only.
  - With none, it says "Morning review: nothing needs your eyes."
  - The ledger `checklist` field holds the same items.
- Step 5 item 3: delete the **Checks** bullet.
- **Asks > Kinds:**
  - Mark `check` as retired: kept in the schema for old rows, never filed.
  - Add a short "is it an ask?" bar with examples:
    - **Yes:** a vendor key, an App Store step, a prod migration apply, a scope decision, a red baseline.
    - **No:** "the card shows this week's minutes", "layout matches canvas", "not screenshotted".
- **Asks > R5:** replace the three check-closing rules with "any open check: resolve with `retired: checks are no longer asks (MCR-2748)`". Before resolving, a check whose text is a real product question is re-filed as `decide-scope`.
- **Step 1b item 3:** applies the new R5 to open checks.
- **Step 1b item 1 (replay):** a queued `upsert` with `kind: check` is not replayed. Drop it with the ledger note `retired check dropped from asks_pending (MCR-2748)`.
- **Exit 1 rule:** a check refused with exit 1 is dropped with a ledger note and never re-sent as another kind.
- **"Not an ask":** a skipped screenshot or other visual evidence goes to `Not eyeballed:`. Only a skipped live read keeps the redo-or-follow-up path.
- **Remove the remaining check-only clauses** so nothing contradicts the retired kind:
  - Keys (KTD2) `Check: ac-<n>`
  - The identity clause "a check filed for a different PR"
  - "A check or human step hangs on its own issue"
  - "Dismiss for checks and follow-ups"
  - The `trigger_pr` / `where_to_look` paragraph
  - The sync-marker "stale (an older PR's check)" note
- Remove the check example and fix-prompt template from the ask-file section. Use a `follow_up` as the example.
- Step 5's status update template: add the `Not eyeballed:` line. Rewrite the `## Morning review` example lines as human items.
- Exit-code rules (exit 1, exit 4): drop "a check … stays in the Morning review".

**Patterns to follow:** the existing `Human batch:` and `Sweep:` header lines (one line, omit at zero). The existing "Not an ask" list.

**Test scenarios:**
- A night that merges three UI issues with untested layout criteria and parks nothing: zero asks filed. The status update has `Not eyeballed: MCR-a, MCR-b, MCR-c` and `Morning review: nothing needs your eyes.` Pulse shows all clear.
- A night that parks one chunk on an App Store step: one `human_step` ask. Morning review has one checkbox line for it. `Not eyeballed:` lists any untested UI criteria.
- An acceptance criterion reading "decide whether the streak resets at midnight or 4am": filed as `decide-scope` with that question, not dropped.
- An unsynced run (token expired) that parked one chunk and filed one follow-up: the human step shows once (under "Needs you"), the follow-up once (as a Morning review line). The `Not eyeballed:` items never show.
- A criterion "backfill populated the prod table" that the builder could not run: redone or filed as a follow-up, never put under `Not eyeballed:`.
- A ledger from an unsynced run holding a queued check upsert: the next run drops it with a ledger note and files nothing.

**Verification:** Reading Step 5 and Asks end to end, no instruction leads to filing a `check`. The status update template's Morning review section matches Pulse's `ITEM_RE` / all-clear contract.

### U2. Helper guard: refuse check upserts

**Goal:** A run that ignores the new rule cannot write a check.

**Requirements:** R1

**Dependencies:** none (lands with U1)

**Files:** `scripts/factory-asks.sh`

**Approach:**
- In the upsert validator (the `ASK_BODY` jq rule set), `kind: check` returns the error `checks are retired (MCR-2748): record it under Not eyeballed; never re-file it as another kind`. This is exit 1 and nothing is sent.
- `resolve` and `open` are unchanged. Resolving an old check by `ask_id` must still work.
- Remove the now-dead check-only validation branches (the `ac-<n>` key, `trigger_pr` / `where_to_look` required).
- `trigger_pr` stays refused on other kinds.
- Update the header comment's kind list.
- Redeploy with `deploy-skills.sh` on **every Mac that runs factories** (this one and the iMac). A Mac whose fast-forward is refused at Step 0 keeps the old helper and contract until it updates.

**Patterns to follow:** the existing jq error lines in `ASK_BODY`, one message per rule.

**Test scenarios:**
- `dry-run upsert` with a `check` ask file → exit 1, message names MCR-2748, nothing printed as a request.
- `dry-run upsert` with a valid `human_step` and a valid `follow_up` → exit 0 (or 3 without a token), unchanged from today.
- A `follow_up` carrying `trigger_pr` → still refused.
- `resolve <old check ask_id> …` → closes the row (exercised in U4).

**Verification:** All four dry-run cases behave as listed. The deployed helper's `--help` / header shows two filed kinds.

### U3. Spec-time gate bar: screens are not a gate

**Goal:** `/packets` stops gating chunks on visual judgment. `judgment:` means a product-direction call.

**Requirements:** R3

**Dependencies:** none

**Files:** `commands/packets.md`, `factory/templates/build-packet.md`, `rules/chunks.md`, `factory/MANUAL.md` (Gate paragraph in the chunk section)

**Approach:**
- **Passages to change:**
  - The trigger list in `commands/packets.md` and `factory/templates/build-packet.md`
  - `rules/chunks.md`: the trigger list ("looking at images or screens to judge them") and the Wizards paragraph ("screens or images", "stays a one-line ask on the morning checklist")
  - `factory/MANUAL.md` Gate paragraph ("look at images or screens and judge them", "stays a checklist line")
  - The `/packets` EARS line "(verified by: <test name or screenshot check>)", which becomes "<test name>"
  - `build-packet.md`'s "Every acceptance criterion is executable" bullet: drop "or it stays a day-shift issue" for eye-only criteria
- **Trigger list, everywhere it appears:** replace "a person judging images or screens (not a scripted screenshot diff)" with "a product-direction call: picking between designs, a taste or naming call, a scope decision". The canvas stage already owns visual approval before build.
- **"A physical device":** stays a trigger only when the build can't proceed without it (provisioning, pairing). Checking behavior on a device is not a gate.
- `judgment:` now reads "a decision only Zack can make". It stays a `human_step` ask. Drop the "stays a checklist ask" wording.
- **Soft rule in `/packets`:** an acceptance criterion a test can prove names the test. One only an eye can judge is accepted as unverified and listed in the run's `Not eyeballed:` record.

**Test scenarios:**
- Re-reading the trigger list against a packet whose only human step is "check the new chart looks right": the rule gives `Human gate: none`.
- A packet whose step is "choose between the two onboarding flows on the canvas": the rule gives `gate:human`, `judgment:`.
- A packet needing an App Store Connect key: `procedure:` with a wizard, unchanged.

**Verification:** The four files state the same trigger list word for word. A case-insensitive search of `commands/`, `rules/` and `factory/` for `images or screens`, `screens or images`, `checklist ask`, `checklist line`, `morning checklist` and `screenshot check` finds nothing.

### U4. One-time backlog sweep

**Goal:** Clear today's open checks across every project now, not only as each project's factory next runs.

**Requirements:** R5

**Dependencies:** U1–U3 merged and deployed on every factory Mac. Confirm on each with a `dry-run upsert` of a check file exiting 1.

**Files:** none committed. The sweep summary goes in an MCR-2748 comment.

**Approach:**
- Build the project list from Linear, not local checkouts. Pulse and Sonar aren't cloned on this Mac. Take every project with a status update starting `Factory ` in the last 30 days.
- For each project, run `factory-asks open <project_id>` and keep the `kind: check` rows.
- Use one run_id for every sweep call: `<today>-sweep-<HHMM>`, e.g. `2026-10-10-sweep-1400`.
- Read each check's text:
  - A product question (rare) is re-filed as a `decide-scope` follow-up on its issue.
  - Everything else is resolved with `retired: checks are no longer asks (MCR-2748)`.
- Post counts per project (resolved, re-filed) on MCR-2748.

**Execution note:** This is an operational pass, not code. Run it attended after U1–U3 merge and deploy, so no night run re-files checks in between.

**Test expectation:** none. This is a one-time data operation. It is verified by the outcome below.

**Verification:** `factory-asks open` returns no `check` rows for any project on that Linear-derived list. Pulse's Build tab shows only human steps and follow-ups.

### U5. Manual and morning ritual

**Goal:** The operating manual describes the new morning.

**Requirements:** R2, R4

**Dependencies:** U1, U3

**Files:** `factory/MANUAL.md`

**Approach:**
- **Stage 6/7 table rows:** "morning checklist" becomes "human batch".
- **Stage 7 "You do":**
  - Step 3 ("walk the checklist") becomes "work the asks in Pulse".
  - Step 4's ten-minute design review stays optional, not a gate.
  - The Gate line: "no open asks at the end of the ritual".
- Replace the "Morning verification checklist" template block with the new status-update shape: `Not eyeballed:` line plus a human-only Morning review.
- The backlog row "Morning checklist emitter" is marked superseded.

**Test expectation:** none. This is documentation only.

**Verification:** MANUAL.md no longer tells Zack to walk acceptance criteria each morning. It matches `commands/factory.md`.

---

## Scope Boundaries

- No Pulse code or schema change. The `check` kind and the Build tab UI stay as they are.
- No change to the chief of staff's Day check block on Pulse's Today page.
- No agent-run visual verification (screenshots, simulator driving) is added to the night shift.

### Deferred to Follow-Up Work

- `docs/software-factory.md` is an unlinked older copy of `factory/MANUAL.md` with the same morning-checklist text. Leave it to the hardening plan's "one source" unit (MCR-2721) rather than edit two copies.
- Pulse cleanup once no check rows remain open: drop check-specific UI and the 14-day expiry copy. Tie it to MCR-2126 (retire status-update checklist parsing) if Zack wants it.

---

## Risks

- **A real UI regression goes unnoticed longer.** This is accepted. The `Not eyeballed:` line makes it traceable to a PR when Zack does notice.
- **Pulse's parser reads the new Morning review lines differently than expected.** Mitigation: U1 keeps the exact `- [ ] MCR-… <title>: <text>` shape and all-clear phrase. Check the first run after merge against the panel.
- **A factory Mac running an old deploy.** It keeps filing checks until it updates, because both guards ship through the same deploy. Mitigation: U4 is gated on the dry-run refusal passing on every factory Mac. A lagging Mac's checks are resolved by the next updated run.

---

## Sources

- `commands/factory.md` Step 1b, Step 5, Asks
- `scripts/factory-asks.sh` upsert validator
- `commands/packets.md`, `factory/templates/build-packet.md`, `rules/chunks.md`, `factory/MANUAL.md`
- `docs/plans/factory-hardening-2026-10-09.md` (106 uncleared items, 0 failed of 229)
- zmcray/Pulse `api/_factory.js` (Morning review parser), `src/components/build/MorningReview.jsx`
