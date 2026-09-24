---
name: packets
description: Turn a finished /ce-plan into build packets...  Turns a plan's Implementation Units into small, parallel-safe Linear chunks... one issue per chunk, each with a build packet, a file-scope fence, blocking edges, and a tier:* difficulty label. Run it right after /ce-plan during spec time. Pairs with the built-in /goal.
argument-hint: "[plan path | Linear issue ID] (default: newest plan in docs/plans/)"
---

# Packets

`/ce-plan` decides **what** to build and cuts it into Implementation Units. `/goal` builds whatever is `spec-ready` in Linear. This command is the only thing between them: it turns one reviewed plan into a set of **chunks** that separate agents (a `/goal` run tonight, Cursor cloud agents later) can pick up independently, some of them at the same time.

It does not plan, re-plan, or second-guess the plan's decisions. If the plan is too vague to chunk, say what is missing and stop... the fix is a `/ce-plan` deepening pass, not invention here.

## Step 1: Resolve inputs

1. **Plan.** Argument is a path → use it. Argument is a Linear issue ID → find the plan whose header names that issue. No argument → newest file in `docs/plans/` (not `archive/`). State the choice in one line.
2. **Linear project.** Read `.linear-project.json` at the repo root (monorepo: the app's own link file). No link file → stop and say to run `/zmcray-kickoff`.
3. **Parent.** If the plan header carries a `Linear Issue`, that issue is the parent: chunks are created as its sub-issues and inherit its milestone, `flow:*`, and `prd-source`. Otherwise create one umbrella issue named after the plan, per AGENTS.md > Linear structure, and hang the chunks under it.
4. **Vocabulary.** Read `CONCEPTS.md` if present. Chunk titles and descriptions use its terms.

**This command is normally invoked for you.** The AGENTS.md rule has any session cut a 3+ unit plan into chunks before building or ending, and every `/goal` run opens with a chunk sweep. Running it by hand is only for spec time when you want to see the waves before bedtime.

**Small-plan no-op.** A plan with 1-2 units that already fits the chunk bar is not split. Add the build packet, `File scope:` line, and `tier:*` label to the existing issue, write a one-row `## Chunks` section into the plan so the sweep does not revisit it, and stop.

## Step 2: Units → chunks

Start from the plan's `### U<N>.` units (Goal, Dependencies, Files, Approach, Test scenarios, Verification). One unit is usually one chunk. Adjust only to meet the bar:

- **Size bar (hard).** One fresh agent context, well under an hour of agent time. Guide rails: about 5 files, about 300 changed lines, one decided approach, 1-4 acceptance checks. A unit over the bar is **split** along its Files list; say how in one line.
- **Verifiable alone.** A chunk must be checkable by itself. A unit that is not (a schema nothing reads, a type nothing uses) is **merged** with its first consumer.
- **One sentence.** If you cannot say what the chunk makes work in one sentence, the cut is wrong.
- Keep the plan's U-IDs in the chunk title (`U3: Grocery list screen`; a split becomes `U3a`, `U3b`) so plan, issue, and PR stay traceable.

## Step 3: File scope, edges, waves

1. **File scope** per chunk = the unit's `Files`, generalized to directories or globs where that is honest. It is a fence: the building agent may not touch paths outside it.
2. **Edges.** Add `blocked by` for every plan `Dependencies` entry. Then run the **overlap check**: any two chunks whose file scopes intersect MUST have an edge (pick the order that lands the more foundational one first). Shared hot files count as overlap and are easy to miss... schema and migration dirs, route or navigation index, DI container, `Package.swift`, lockfiles, generated types, shared design tokens.
3. **Widen the waves.** If one shared file forces a long serial chain, propose a small **prefactor chunk** that isolates the seam (extract the registry, split the index), then fan the rest out behind it. Propose it; do not silently add scope. Taste call → ask once, batched.
4. **Waves.** Wave 1 = chunks with no blockers. Wave N+1 = chunks unblocked once wave N merges. Chunks inside a wave share no files and may be built simultaneously. Merges are always one at a time.

## Step 4: Tier triage

Exactly one per chunk. Judge how hard it is to get **right** (novelty, ambiguity, subtlety, how much must be held in mind at once)... not size, not blast radius:

- `tier:mechanical` ... one obvious approach, pattern already in the repo. Copy, config, a field end to end, test backfill, a rename batch.
- `tier:moderate` ... familiar reasoning against a settled spec. Most chunks.
- `tier:judgment` ... novel, several plausible approaches, or concurrency / security / data-correctness traps.

**Never write a model name in an issue.** The tier-to-model map lives in `software-factory/DISPATCH.md` and is applied at dispatch. Note the floor: even `tier:mechanical` is built by a model that writes code well (sonnet today); the cheapest model only reads. If more than about a third of the chunks are `tier:judgment`, the cut is too coarse: split until the hard part sits in one or two chunks. State each call in one line.

## Step 4b: Human-gate triage

For every chunk ask: **can this finish overnight with nobody present?** Apply `gate:human` when any step needs a person: a human judging images or screens (not a scripted screenshot diff), credentials / 2FA / App Store or a vendor console, a physical device, a taste or naming call, an outside party. Write the packet's `Human gate:` line as one sentence naming what the person does and when (`before build`, `mid-build`, `before merge`). Chunks with no such step get no label and `Human gate: none`. A `gate:human` chunk never enters the night queue; `/goal` skips it. Prefer splitting so the human step is its own small chunk and the rest stays hands-off. State each call in one line.

## Step 5: Write the chunks to Linear

One issue per chunk, created in dependency order so edges can reference real IDs. Follow AGENTS.md > Linear structure (milestone required, priority never None, sub-issues inherit the parent's milestone).

- **Title:** `U3: <imperative, one line>`
- **Labels:** the parent's `flow:*`, exactly one `tier:*`, `spec-ready`, `prd-source` if the parent has it, and `gate:human` from Step 4b where it applies. Never apply `night-eligible`... that label is human-applied.
- **Relations:** native `blocked by` links from Step 3.
- **Body** (the build packet, `software-factory/templates/build-packet.md`):

```
## Build packet
Spec: <plan path> § U3  (planned and reviewed... execute this unit only, do not re-plan)
Acceptance criteria:
- WHEN <trigger>, the system SHALL <behavior>   (verified by: <test name or screenshot check>)
Artboard: <approved canvas link from the plan, or "n/a (no UI)">
File scope: <dirs / globs>
Out of scope: <what this chunk deliberately does not do; name the sibling chunks that own it>
```

Acceptance criteria come from the unit's Test scenarios and Verification, rewritten so each names the check that proves it. A criterion a machine cannot check is rewritten or the chunk loses `spec-ready` with a comment saying why. Describe behaviour and interfaces, not line numbers.

If a `tier:*` label does not exist in the workspace yet, create it (workspace-level) and continue. If Linear is unreachable, write the same packets to `docs/plans/chunks/<plan-slug>/NN-<slug>.md`, say so plainly, and stop before the handoff.

## Step 6: Summary and handoff

Print: chunk count · tier mix · the waves (IDs per wave) · any split, merge, or prefactor decisions in one line each · anything that failed the bar. Append a `## Chunks` section to the plan file listing `U-ID → issue ID → wave → tier`, so the plan stays the index.

Close with: **"[N] chunks spec-ready on [project], [W] waves, widest wave [K]. Tonight: `/goal <parent ID>`."**

## Notes

- Re-running on the same plan is safe: match existing chunks by U-ID in the title and update them rather than duplicating.
- Today a `/goal` run builds one chunk at a time with `/lfg`, in edge order, and treats `tier:*` as advice for its subagent model choice. Parallel waves and per-chunk model dispatch arrive with the Cursor cloud lane (software-factory Phase 2). Cutting the work this way now is what makes that switch free later.
- `flow:ship` one-liners do not need this command... they go straight to `/lfg`.
