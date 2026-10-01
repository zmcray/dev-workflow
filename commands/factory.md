---
name: factory
description: The night shift. With no arguments, drains everything spec-ready in this repo's Linear project overnight under a budget (stop time, 12-hour run limit), skips anything that needs a human, and leaves a run ledger plus a morning report. Wraps the harness's goal mode (Claude Code, Codex, or Cursor); the build rules stay in AGENTS.md. Use for "/factory", "run the factory", "start the night shift", "drain the queue". NOT for a single issue (/lfg) or a named objective (/goal <objective>).
argument-hint: "(none) | --dry-run | --stop-at HH:MM | --max-hours N"
---

# Factory

`/packets` fills the queue during the day. `/factory` drains it at night and stops before you wake up. It adds exactly four things on top of AGENTS.md > Autonomous runs: a queue read with no argument, a budget checked before every chunk, a ledger the morning can read, and a stored list of what the run needs from Zack (asks) that Pulse shows until he closes each one. Everything about how a chunk is built (chunk sweep, pull order, human parks, merge on green, session close, delegation by tier) is the existing goal-mode contract and is not restated here. If a build rule needs to change, change AGENTS.md, not this file.

Standing contract: **never ask the user anything.** Every would-be question is a one-line judgment call logged to the relevant Linear issue. The only exits are the four endings in `~/Developer/software-factory/DISPATCH.md`: queue empty, budget stop, human park (per chunk, run continues), hard stop.

**One file, three harnesses.** Source lives in `~/Developer/dev-workflow/commands/factory.md` and `deploy-skills.sh` ships it to Claude Code (`~/.claude/commands/`) to Codex (`~/.agents/skills/factory/`), and to Cursor (`~/.cursor/skills/factory/`). Everything harness-specific is in **Running on each harness** at the bottom; the steps above it are the same everywhere. Edit the source, not a deployed copy (the skill sync captures an in-place edit and proposes it, but only a merge makes it real).

## Step 1: Resolve the repo and the budget

**Before anything: run on the approved skills.** Both Macs must start the night on the same merged version of `dev-workflow` and `software-factory`, never on another Mac's unmerged edits (MCR-2353). Run `git -C ~/Developer/dev-workflow fetch -q` and the same for `software-factory`. If either main checkout's `HEAD` is behind `origin/main`, run `bash ~/Developer/dev-workflow/scripts/sync-skills.sh` (it installs merged changes only and re-deploys every skill), then **re-read this command from disk** (Claude Code: `~/.claude/commands/factory.md`; Codex: `~/.agents/skills/factory/SKILL.md`; Cursor: `~/.cursor/skills/factory/SKILL.md`) and follow the new text from here, because this session loaded the old one. Then record both repos' `HEAD` short SHAs in the ledger as `"skills": { "dev_workflow": "<sha>", "software_factory": "<sha>", "local_edits": <true|false> }`, where `local_edits` is true when either checkout has changes not on `origin/main` (this Mac's own unmerged edits: allowed, and named in one line under Notes in the status update). A sync failure is not a hard stop: note it the same way and run on what is installed.

0. **Preflight.** Before anything else, prove the run can finish without a person: a Linear tool answers (list one issue from the project), `gh auth status` passes, and a trial `git fetch` does not stop for approval. Any failure is a hard stop now, with the missing piece named in one line. A shift that stalls at 2am on an approval prompt is worse than one that never starts. Record which harness is running as `lane` (`claude`, `codex`, or `cursor`), and this run's **`run_id`**: `<YYYY-MM-DD>-<lane>-<HHMM>`, the start date and time in ET (`2026-09-30-claude-2340`). The run_id names this run everywhere: the ledger, every ask it files, its sync marker, and `run:<run_id>` in the first line of its status update. Pulse matches it exactly, so never reformat it mid-run.
1. **Project.** Read `.linear-project.json` at the repo root (monorepo: the app's own file). No link file → stop and say to run `/zmcray-kickoff`. `"automerge": false` → stop; a factory run cannot leave PRs queued.
2. **Budget.** Merge, lowest to highest precedence: defaults from `~/Developer/software-factory/DISPATCH.md` > Night budget → the `factory` key in `.linear-project.json` → flags on this invocation.

```json
"factory": { "stop_at": "06:00", "max_hours": 12, "concurrency": 1, "max_turns_per_chunk": 150 }
```

3. **Deadline math.** Two clocks, and whichever trips first ends the shift. There is no chunk cap: the night builds as many chunks as the clocks allow.
   - **Stop time.** `stop_at` is local time, tomorrow if it is already past. `last_dispatch = stop_at - 45 min`. No chunk starts after `last_dispatch`.
   - **Run limit.** `hour_limit = started_at + max_hours`. Once the run has been going `max_hours`, no new chunk starts; the chunk already in flight finishes and the shift closes.
   - Nothing is ever killed mid-PR. A leftover `max_chunks` key in a link file is retired and ignored.
4. **Asks check.** Run `test -x ~/.local/bin/factory-asks && ~/.local/bin/factory-asks check`. It prints the writer token's expiry, never the token. A missing helper, or exit 3 (token missing, expired or unreadable), is **not** a stop: hold the reason as the asks warning (see **Asks** below), queue tonight's helper calls in `asks_pending` instead of sending them, and go on. A renewal notice in its output goes in the status update.
5. **Baseline.** Fresh default branch, CI green on `main`, working tree clean. Red baseline is a hard stop before anything is pulled: run Step 1b, write the Step 3 ledger with nothing eligible, then go to Step 5, which files a `restore-baseline` follow-up. That night's docs PR cannot merge on a red `main`: leave it open and say so in the status update.

## Step 1b: Asks at run start

Before the queue, so the night knows what is already waiting on Zack and never files it twice. The rules (keys, runbooks, what closes) are in **Asks** below. In this order:

1. **Replay `asks_pending`.** Earlier ledgers in `docs/factory/runs/` (the last 7 days) may hold calls a run could not send. Move each entry out of its old ledger and send it again (`upsert` from the stored ask, `resolve` from its stored arguments). An entry that fails again with exit 2 or 3 goes into this run's `asks_pending`; exit 4 is dropped with a one-line note in this run's ledger. Entries are moved, never copied, so no call is sent twice.
2. **Read open asks.** `~/.local/bin/factory-asks open <project_id>` prints the project's open asks, one JSON row each (id, issue, kind, key, generation, trigger_pr, first seen). Keep them for the rest of the run.
3. **Resolve per R5.** Read each open ask's issue in Linear (state, labels, merged PRs) and close what the rules close, with `~/.local/bin/factory-asks resolve <ask_id> <project_id> <run_id> "<why, one line>"`.
4. **Upsert human steps, for actionable gates only.** For each open `gate:human` issue in the project whose person-only step can be done now (KTD4, below), `~/.local/bin/factory-asks upsert` a `human_step` ask with key `gate`. An open ask for the same gate is refreshed, not duplicated.

With an asks warning from Step 1.4, send nothing: move every earlier `asks_pending` entry into this run's, and queue the resolves and human steps you would have sent there too, so a renewed token catches up next run. Hold the counts (open at start, resolved, written); Step 3 writes them into the ledger.

## Step 2: Read the queue

Query the project's issues: `spec-ready`, state type not started/completed/canceled, not `gate:human`, not `ops`, no open `blocked by`. Then drop any issue labeled `design:screens`, `design:journey`, or `design:product` that has no canvas link (a Linear attachment, or a `Canvas: <url>` or `Artboard: <url>` line in the description). That is the AGENTS.md Spec gate: `spec-ready` without a canvas means someone skipped the design block, and the night never builds screens nobody drew. Order: priority (Urgent > High > Medium > Low), then wave from the parent plan's `## Chunks` table when the issue is a chunk, then oldest first.

Run the **chunk sweep** first, exactly as AGENTS.md describes it, so plans written today are cut before the queue is read.

Print the shift plan once and start. No confirmation.

```
Factory: <project>. <E> eligible, no new chunk after <last_dispatch> or <hour_limit> (whichever is first), stop by <stop_at>.
Skipped: <n> gate:human (<IDs>), <n> ops, <n> blocked, <n> no-canvas (<IDs>).
Order: <IDs in order>.
```

`--dry-run` prints this and stops. It is the only argument that changes behaviour beyond the budget.

## Step 3: Open the ledger

Write `docs/factory/runs/YYYY-MM-DD.json` in the repo (create the directory; it is committed with the morning docs PR, never with a chunk PR). If that file already exists (another lane or a rerun the same day), write `docs/factory/runs/<run_id>.json` instead: never overwrite an earlier run's ledger.

```json
{
  "run_id": "2026-09-23-claude-2340",
  "project": "Pulse",
  "lane": "claude",
  "started_at": "2026-09-23T23:40:00-04:00",
  "budget": { "stop_at": "06:00", "last_dispatch": "05:15", "max_hours": 12, "hour_limit": "11:40", "concurrency": 1 },
  "eligible": ["MCR-1710", "MCR-1711"],
  "skipped": [{ "issue": "MCR-1714", "reason": "gate:human" }, { "issue": "MCR-1716", "reason": "no-canvas" }],
  "items": [],
  "asks": { "open_at_start": 0, "resolved": 0, "written": 0, "synced": false, "warning": null },
  "asks_pending": [],
  "stopped_at": null,
  "stop_reason": null
}
```

`asks.warning` is one line (`token expired on 2026-12-29`, `helper missing`, `server unreachable`) or null. Each `asks_pending` entry is a call that did not go through: `{ "op": "upsert", "ask": { ...the ask file... } }` or `{ "op": "resolve", "args": ["<ask_id>", "<project_id>", "<run_id>", "<note>"] }`.

Every item row is written **when the chunk starts** and updated when it ends, so a dead session still leaves a readable file:

```json
{ "issue": "MCR-1710", "tier": "moderate", "model": "opus", "started_at": "...", "ended_at": "...",
  "status": "done | interrupted | parked | skipped-budget | skipped-conflict | failed",
  "pr": "https://github.com/...", "turns": 0, "retries": 0, "note": "one line" }
```

## Step 3b: Write the morning wizards

Before the first chunk, so the human batch is ready even on a short night. Find the project's open `gate:human` issues whose human step is a **procedure** (AGENTS.md > Wizards for human procedures) and that have no `Wizard:` line in the description or comments. A `Human gate:` line without a `procedure:` or `judgment:` prefix is classified from its wording; unsure means judgment, no wizard. Highest priority first, at most 5 a night; the rest wait for tomorrow.

For each, write the wizard with the `wizard` skill (unattended rules in AGENTS.md), all of them in one `chore:` PR with no issue IDs in the branch, title or commit subjects and `Part of MCR-…` lines in the body, so the issues stay open. Merge on green, then comment `Wizard: bash scripts/wizards/<file>.sh` on each issue with the stage list. Record `"wizards": [{ "issue", "file" }]` in the ledger. A red wizard PR is not a hard stop: close it, note it in the ledger, and start the shift.

## Step 4: The shift

Arm the harness's goal mode (see **Running on each harness**) with this condition and let it drive:

> Goal: drain the factory queue for <project> under the budget in `docs/factory/runs/<date>.json`. Before starting any chunk: re-read the ledger, stop if the clock is past `last_dispatch` or past `hour_limit`, re-query Linear for the next eligible issue (the board may have changed). Build each chunk per AGENTS.md > Autonomous runs. Update the ledger row at start and end of every chunk. Ending conditions are queue empty, deadline, run limit, or hard stop; write `stop_reason` and finish with Step 5.

The budget check happens **between chunks, never inside one**. A chunk that is running at `stop_at` or `hour_limit` finishes; it is the 45-minute margin's job to make the `stop_at` case rare. The run limit has no margin: at `hour_limit` the in-flight chunk completes and nothing new starts.

Per-chunk delegation follows DISPATCH.md: the builder gets the model (or reasoning setting) in the running harness's column for the chunk's `tier:*`, and `max_turns_per_chunk` as its turn cap. Two failed attempts on one chunk (one tier up on the retry) mark it `failed`, post the comment, and move on... a failed chunk is not a hard stop unless its branch broke `main`.

`concurrency` above 1 is reserved for the wave dispatcher (one worktree subagent per chunk in a wave, merges still one at a time). Until that lands, set it to 1 and the run is sequential.

## Step 5: Close the shift

1. Write `stopped_at` and `stop_reason` (`queue-empty | deadline | hour-limit | budget | hard-stop`) to the ledger.
2. **One consolidated morning checklist, never one per issue, and only what needs a person.** Go through every merged issue's acceptance criteria (MANUAL §7). A criterion that a merged test asserts is **dropped**: CI already verified it and the human does not see it. Keep only what CI cannot prove: UI or layout, a live-schema or prod read the builder could not run, anything the builder noted as "not run" or "not screenshotted", a taste call. Group what is left by issue under `## Morning review` in the status update (item 4). Zero items left → write `Morning review: nothing needs your eyes.` Merged issues close to Done on merge (GitHub integration); the checklist is the review surface, and a kick back reopens the issue. Write the same list to the ledger as `"checklist": [{ "issue", "title", "criterion", "where" }]` so Pulse can render it. Per-issue merge comments keep the PR summary and judgment calls but **do not** carry a checklist block; they end with one line: `Morning review: see the Factory <date> status update.`
3. **File the asks** (rules in **Asks** below), in this order:
   - **Checks.** Upsert one `check` per Morning review item from item 2: key `ac-<n>`, `trigger_pr` = the PR that merged the issue, `where_to_look` from its `Where to look:` line, a runbook, and the fix prompt.
   - **Follow-ups.** Upsert one `follow_up` per thing the night needs Zack to decide or do that is not a gate: a scope kick-back (`decide-scope`), a migration to apply (`apply-migration`), a red baseline (`restore-baseline`), a blocked dependency (`unblock-dependency`), anything else as `other-<slug>`. Set `seen_again: true` when Step 1b found an earlier generation of the same key closed and the cause is back tonight.
   - **Human steps, second pass.** Run the Step 1b item 4 pass again, for issues parked tonight.
   - **Sync marker.** When no call tonight ended in exit 2 or 3, run `~/.local/bin/factory-asks record-sync <project_id> <run_id> <written>` and set `asks.synced: true`. `<written>` counts the upserts that came back `action=inserted` or `action=refreshed`; `unchanged` (an ask Zack already closed) and `stale` (an older PR's check) are not written. When any call ended in exit 2 or 3, skip the marker, queue those calls in the ledger's `asks_pending` (the next run replays them), and set `asks.warning`. A call dropped with exit 1 or 4 does not block the marker: its item stays in the Morning review and the ledger notes why. Never record a marker for a run whose asks did not all land: Pulse reads the marker as "this run's list is complete".
4. Post **one project status update** in Linear (health per the run: on track for queue-empty or hour-limit, at risk for deadline with parks, off track for hard stop):

```
Factory <date> (<lane>, run:<run_id>): <k> merged, <p> parked for a human, <f> failed, stopped: <reason> at <time>.
Asks: <w> filed, <r> resolved, <o> open. (or) Asks not synced: <asks.warning>. The Morning review below is the record for this run.
Merged: MCR-… (PR), MCR-… (PR)
Human batch: MCR-… — <one-line ask> (procedure: `Run: bash scripts/wizards/<file>.sh`)
Needs design first: MCR-… → brief docs/design/briefs/<file> (spec-ready but no canvas; write the brief per AGENTS.md > Design brief if none exists; omit the line at zero)
Failed: MCR-… — <one line>
Next: <first eligible issue left in the queue, or "queue empty: plan first">

## Morning review   build: <preview URL or main @ sha>
- [ ] MCR-… <title>: <criterion a person must look at or do>
Where to look: <tab / screen / URL>
```

   **The first line starts `Factory <date> (<lane>, run:<run_id>)`**, exactly. Pulse keeps only updates that start with `Factory `, reads the date from that line, and matches `run:<run_id>` against the sync markers; a run id anywhere else counts as unsynced. Keep the `## Morning review` section even when the asks synced: it is the human-readable record.
   **Times are ET (America/New_York), always.** Every time a human reads (status update, checklist, merge comments) is written in ET, e.g. `6:00 AM ET`, never UTC. Convert cron and workflow schedules (`10:00 UTC` → `6:00 AM ET` in EDT, `5:00 AM ET` in EST) using the date the reader will act on.
5. Open a `docs:` PR with the ledger file (and any earlier ledger whose `asks_pending` changed) and any archived plans, merge on green. It is the last PR of the night.
6. Close with one line: **"Factory done: <k>/<E> merged, stopped on <reason>. Morning batch: <p> issues, <w> with a wizard. Asks: <o> open (<synced | not synced: reason>)."**

## Asks

Everything a run needs from Zack is also stored as an **ask**: a row in `os.factory_asks` on mcray-os. Pulse's Build tab shows each open ask until Zack closes it (Done, or Dismiss for checks and follow-ups), whatever night filed it. Pulse, never the factory, tells Linear about a close. The factory reaches the table only through `~/.local/bin/factory-asks` (source `scripts/factory-asks.sh` in dev-workflow, installed by `deploy-skills.sh`), which reads the writer token from the Keychain and never prints it. Always call it by that full path: `~/.local/bin` may not be on the harness's PATH.

**Kinds.**
- `check`: a merged issue's acceptance criterion that CI cannot prove; one per Morning review item.
- `human_step`: the person-only step of a `gate:human` issue.
- `follow_up`: anything else the night needs Zack to decide or do.

**Every ask hangs on one Linear issue.** A check or human step hangs on its own issue; a follow-up on the issue it is about. A follow-up with no issue (a red baseline, a broken shared dependency) hangs on a Bug filed for the break in `Platform: hardening`, or on the open one already there for the same break.

**Keys (KTD2). Rule-based, never invented per run:**
- Human step: `gate`.
- Check: `ac-<n>`, the criterion's position in the issue's full acceptance list, before CI-proven criteria are dropped. Rewording a criterion refreshes the same row.
- Follow-up: a slug from this list, `decide-scope`, `apply-migration`, `restore-baseline`, `unblock-dependency`, or `other-<slug>` (kebab-case, at most 30 characters, derived from the ask). The RPC validates the shape.

An ask's identity is its issue's UUID, kind and key. Filing it again refreshes the open row (text, steps, prompt, last seen). A closed ask never reopens; a new generation opens only for a human step whose last one was done or resolved, a check filed for a different PR, or a follow-up whose last one was done or resolved and that carries `seen_again: true`.

**Human steps for actionable gates only (KTD4).** File a `human_step` only when the step can be done now: the issue was parked mid-build (a park comment or a draft PR), or its packet's `Human gate:` line puts the step before the build. A post-PR gate on an unbuilt chunk gets no ask until the factory parks it at that step. Zack's Done on a human step removes `gate:human`, which puts the issue back in the queue.

**What closes an ask (R5).** The factory resolves, with a one-line reason:
- human steps and follow-ups whose issue is Done or Canceled;
- human steps whose issue no longer carries `gate:human`;
- checks 14 days after `first_seen_at`, checks whose issue was Canceled, and checks whose issue has a merged PR newer than the ask's `trigger_pr`.

Nothing else closes an ask. Zack closes the rest in Pulse.

**The ask file.** One JSON object per ask, written to a temp file and sent with `~/.local/bin/factory-asks upsert <file>`. Validate first with `~/.local/bin/factory-asks dry-run upsert <file>`, which prints the request and sends nothing. Exit 0 or 3 from a dry run means the ask is valid (3 only says there is no usable token); exit 1 lists what to fix.

```json
{
  "linear_issue_id": "<the issue's UUID from the Linear tool, not MCR-123>",
  "issue_identifier": "MCR-123",
  "project_id": "<id from .linear-project.json>",
  "project_name": "<name from .linear-project.json>",
  "kind": "check",
  "ask_key": "ac-2",
  "ask": "Check the Zone 2 card shows this week's minutes",
  "prompt_md": "<the fix prompt below, filled in>",
  "steps": [
    { "text": "Open Pulse on the preview", "action": { "type": "open", "value": "https://<preview URL>" } },
    { "text": "Today > This week > tap the Zone 2 card" },
    { "text": "Compare the minutes with Strava's weekly total" }
  ],
  "done_when": "The card's minutes match Strava's weekly total",
  "run_id": "2026-09-30-claude-2340",
  "trigger_pr": 123,
  "where_to_look": "Today > This week > Zone 2 card"
}
```

`trigger_pr` and `where_to_look` are for checks only, and both are required there. A human step or follow-up with a wizard adds `"wizard": "bash scripts/wizards/<file>.sh"`. A follow-up whose cause came back adds `"seen_again": true`.

**Runbook (KTD14).** Every ask is runnable without context: Zack opens it and knows what to do next.
- 1 to 8 numbered steps. Each is one plain instruction on one line, at most 200 characters, with at most one action: `open` (an `https://` URL only), `run` (one shell command of at most 300 characters, which Pulse shows with a Copy button and never runs), or `copy` (text of at most 500 characters).
- Steps name exact places: a screen path ("Today > This week > tap the Zone 2 card"), a URL, a file, a command. "Verify X works" is not a step.
- Write them from what the build actually touched (the screens, URLs, commands and TestFlight build in the diff and the PR), never guessed. Where the exact path is not known from the repo or the vendor's docs, the step says so and links the docs: no invented clicks (the wizard rule).
- A human step with a wizard makes running the wizard one of its steps: a `run` action whose value equals `wizard`.
- `done_when`: one line of at most 300 characters saying what good looks like, so Zack knows when to press Done.
- No secrets in any field. The helper refuses a malformed runbook, a bad key or a secret before anything is sent, and the RPC checks it all again.

**Prompt for a human step or follow-up** (`prompt_md`, 5 to 10 lines; it starts the work in a fresh session):

```
<What to do, in one sentence.> This is <MCR-123>: <issue title>.
<With a wizard: Run `bash scripts/wizards/<file>.sh` from the repo root and follow its stages.>
<Context the next session needs, one or two lines: the PR, the park comment, the options for a decision.>
Done looks like: <done_when>.
Report back on <MCR-123>: what you did and anything that surprised you.
```

**Fix prompt for a check** (`prompt_md`, 5 to 10 lines; Zack copies it when the check fails):

```
This check failed. <MCR-123>: <issue title>, shipped in <PR URL>.
The criterion: <the acceptance criterion as written>.
The step that failed: step <n>, "<step text>".
What I saw: <Zack fills this in>
Reproduce it, then fix it on a branch, or file a Bug in the issue's `<Epic>: hardening` milestone if it is bigger than a fix.
```

**Not an ask.** An item with nothing for Zack to do stays in the status update's prose:
- a report of what shipped;
- a note that the run skipped its own evidence (a screenshot, a live read): the factory redoes it, or files a follow-up for the part only Zack can do;
- a question hidden in a criterion: that becomes a `follow_up` with key `decide-scope` and the real question.

**When the helper cannot write.** Its exit code says what to do; the run never stops for asks.
- **Exit 1** (the helper refused the ask; nothing sent): fix the ask and send it once more. A second refusal is a one-line ledger note, and the item stays in the Morning review.
- **Exit 2** (unreachable, timed out, rate-limited, server error): queue the call in `asks_pending`; the next run replays it.
- **Exit 3** (no usable token, or a missing tool) or a missing helper: queue the call in `asks_pending`, set `asks.warning`, and write `Asks not synced: <reason>` in the status update.
- **Exit 4** (the server refused the call for good: `invalid_*`, `secret_detected`, `project_mismatch`, `ask_not_found`): never queue or retry it. Note it in the ledger; a check or follow-up stays in the Morning review.

A resolve that finds the ask already closed (Zack pressed Done first) exits 0. Pulse shows every stored open ask whether or not tonight's marker landed, and says "asks not synced for this run" when it did not.

## Notes

- **Do not shadow built-ins.** This command wraps goal mode; it must never be renamed to `goal`, `loop`, or `schedule` (D-022). Claude Code, Codex, and Cursor all ship a built-in with at least one of those names.
- **Anything the harness refuses to run unattended is a human gate.** A prod migration apply, a dashboard toggle, a command that returns pending approval (Claude's auto-mode classifier, a Codex sandbox escalation, a Cursor run prompt). Park it, do not wait on it. If `/packets` missed the gate, say so in the morning report so the packet rule improves.
- **iOS repos.** One Mac runner builds one PR at a time, so land chunks in groups (AGENTS.md > Landing: group PRs): CI runs once per group, not per chunk. The clocks stop the run, same as web.
- **Spend cap.** Not enforced interactively. When the factory moves to a headless Routine launch, pass `--max-budget-usd` and add `budget` as a stop reason.

## Running on each harness

Steps 1 to 5 do not change. Only three things do: how the shift is started, how goal mode is armed, and who builds each chunk.

| | Claude Code | Codex | Cursor |
|---|---|---|---|
| Start | `/factory` | `$factory`, or "run the factory" | `/factory`, or "run the factory" |
| Goal mode (Step 4) | built-in `/goal <condition>` | Codex goal mode if this build offers it; otherwise stay in this turn and loop Step 4 yourself, never ending the turn between chunks | built-in `/goal <condition>` (its `CreateGoal` tool) |
| Build one chunk | Compound Engineering `/lfg` in a builder subagent | Compound Engineering `lfg` skill, in the main thread (Codex runs CE subagents sequentially) | Compound Engineering `lfg` skill, in a subagent when the model supports it |
| Model per `tier:*` | DISPATCH "Claude Code" column | DISPATCH "Codex" column (reasoning effort) | DISPATCH "Cursor cloud agent" column |
| Unattended setup | auto mode | `approval_policy = "never"`, `sandbox_mode = "workspace-write"` with network on, for the repo | auto-run on for the repo, Linear MCP enabled |

- **Tool names.** Where a step names a Claude tool (`Agent`, `AskUserQuestion`, `Skill`), use the harness equivalent. On Codex the Compound Engineering tool map in `~/.codex/AGENTS.md` is the translation table. `AskUserQuestion` never applies here: the factory does not ask.
- **Linear.** Every harness needs its own Linear connection (MCP or connector). Step 1.0 checks it. Without it there is no queue, no ledger updates on issues, and no morning status update.
- **One harness per night per repo.** Two harnesses draining the same project race on `spec-ready` issues and on `main`. The ledger's `lane` says who ran; the fallback order is in DISPATCH.md.
