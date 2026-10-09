<!-- Moved from the canonical AGENTS.md block (MCR-2720). Read on demand; binding when it applies. -->

# Delegation

Read before any step that runs more than a couple of tool calls.

## Delegation (subagents and model tiers)

A third axis, orthogonal to flow and effort. Flow decides which phases run, effort decides how hard the model reasons, delegation decides *who does each piece and at what cost*.

**The tier assessment is mandatory, not optional.** Before starting any step that runs more than a couple of tool calls, assess whether a lower-tier subagent can do it and state the call in one line: **"Delegating [work] → [tier] ([why])"**, or **"Main thread: [work] ([why it needs judgment])"**. The default answer is delegate-and-downshift. Work stays in the main thread on the frontier model only when it genuinely requires judgment; "it's faster to just do it here" is not a reason. Main-thread context is the scarcest resource in a run... spend it on decisions and synthesis, never on file dumps, log tails, or status polling.

When model selection is exposed, tier by work type — **reading → cheapest tier, code at any difficulty → sonnet or better, judgment → Fable**. The cheapest model never writes code; it explores, reduces, polls and formats.

| Work | Tier | Claude Code model |
|---|---|---|
| Repo exploration, multi-file reads, existing-pattern discovery, dependency audits, TODO/FIXME scans, Linear comment formatting, duplicate-issue checks. **Read-only or prose only, never a code diff** | read | `haiku` |
| Code with one obvious approach: copy, config, a field end to end, test backfill, a rename batch, mechanical transcription (issue spec → plan file), PROJECT.md / Build Log edits (`tier:mechanical` chunks) | mechanical | `sonnet` |
| **GitHub and CI work** (see the rule below): polling, log reduction, PR body assembly on `haiku`; workflow YAML edits and anything that produces a diff on `sonnet` | read → mechanical | `haiku` → `sonnet` |
| Per-file review passes, test-suite triage, implementation slices against a settled spec, drafting a spec from decisions already made, summarizing what a read pass found (`tier:moderate` chunks) | moderate synthesis | `opus` |
| Flow triage, effort setting, plan approval, architecture calls, scope and taste judgment, root-causing a CI failure, the merge decision, anything the human will be asked to decide (`tier:judgment` chunks) | judgment | `fable` (main thread) |

**GitHub / CI operations run on the cheapest tier that can do them.** Delegate to `haiku` (escalating to `sonnet` only when output needs real interpretation): CI watch and check-status polling, fetching and reducing Actions run logs to the failing lines, PR body assembly, authoring or editing Actions workflow YAML, and label / secret / branch plumbing across multiple items. The main thread receives the *reduced* result — the failing test name and error, not the log. Deciding what a failure means and whether to merge stays frontier. Exception: a single one-shot `gh` call (one `gh pr view`, one `gh pr merge`) stays inline — a subagent round-trip costs more than the call. The rule targets anything that loops, polls, or returns bulk output.

Tier names are owned by the tool and change over time... map by intent to what your harness currently offers (Claude Code today: `haiku` / `sonnet` / `opus` / `fable` on the subagent `model` param; Codex and Cursor: default unless exposed). Do not hard-code a tier name into a plan or an issue. If subagents are unavailable, do the work in the main thread and say so once.

**Escalate on failure, not on suspicion.** Start a delegated subtask at the lowest plausible tier. If the result comes back incomplete, low-confidence, or wrong, re-run it one tier up rather than absorbing it into the main thread. Two failed tiers on the same subtask means the work needed judgment all along... pull it back and reclassify. Never pre-emptively route to frontier because a cheaper tier *might* struggle.

**Fan out in parallel.** Independent delegated subtasks are dispatched in a single message with multiple subagent calls, never one at a time.

**Parallel tool calls:** when making multiple tool calls with no dependencies between them (independent file reads, searches, status checks), issue them in parallel rather than sequentially, using whatever batching mechanism your harness provides (e.g. Codex's `multi_tool_use.parallel`; Claude Code batches independent calls in one turn natively). Sequence calls only when a later call needs an earlier call's result.
