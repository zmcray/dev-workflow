---
name: zmcray-retro
description: Cross-project retrospective that promotes durable learnings to the base template
argument-hint: "[optional: specific project or timeframe to retro]"
---

# Retro

System-level retrospective. Scans compound learnings across all projects, extracts durable patterns, and promotes them to CLAUDE-base.md so every future project inherits them. Run this from the parent Projects folder (30_Projects/), not from inside a specific project.

## Delegation & Model Policy

Apply the AGENTS.md Delegation section. **State the tier before each step that runs more than a couple of tool calls.** A retro is mostly bulk reading, which is exactly the wrong thing to spend frontier context on:

- **`haiku`:** Step 1's scan (fan out — one subagent per project directory, dispatched in parallel, each returning that project's learning entries as a compact list, not the file), and Step 6's mechanical pruning/archiving edits once the main thread has decided what goes.
- **`sonnet`:** clustering the collected entries by theme and drafting the promoted rule text.
- **Main thread (frontier):** the Step 2 contradiction calls, the Step 3 answers, deciding what is genuinely durable, and every Step 5 conflict resolution. A bad rule in the base template affects every future project — that judgment never gets delegated.

## Step 1: Scan All Projects

Find every project CLAUDE.md that has a `## Compound Learnings` section. Search all subdirectories:
- `30_Projects/McRayGroup/*/CLAUDE.md`
- `30_Projects/Clients/*/CLAUDE.md` and `30_Projects/Clients/*/*/CLAUDE.md`
- `30_Projects/Atlas_OS/CLAUDE.md`
- Any other project directories with a CLAUDE.md

For each project found, read the Compound Learnings section and note: project name, tier, and all learning entries with their dates and categories.

If the user specifies a project or timeframe, filter accordingly. Otherwise, scan everything.

## Step 2: Cross-Project Analysis

Group the learnings across all projects. Look for:

1. **Repeated patterns:** The same insight showing up in 2+ projects (even if worded differently). These are the strongest candidates for promotion.
2. **Contradictions:** Learnings from one project that conflict with learnings from another. Surface these for the user to resolve.
3. **Category clusters:** Multiple learnings in the same category (arch, testing, process, etc.) that could consolidate into a single rule.

Present a brief summary to the user organized by theme, not by project. Reference which projects each pattern came from. Wait for the user to confirm, add, or edit before proceeding.

## Step 3: Retrospective Questions

Answer three questions based on the cross-project view. Be specific, reference actual projects and outcomes. No generic platitudes.

1. **What's working across the board?** Patterns, tools, or decisions that consistently produce good results.
2. **What keeps hurting?** Recurring friction, repeated mistakes, or assumptions that keep being wrong.
3. **What should change system-wide?** Concrete adjustments to the base template, tier definitions, or build workflow.

## Step 4: Extract Durable Learnings

From the analysis and retro, extract learnings that apply beyond any single project. A durable learning is one that would help on a project that doesn't exist yet.

Format each learning as a single line:
`- [YYYY-MM-DD] [category] Learning text. (Source: [project1], [project2])`

Categories: `arch`, `testing`, `perf`, `dx`, `tooling`, `process`, `pattern`

## Step 5: Promote to CLAUDE-base.md

Open `30_Projects/00_Code/CLAUDE-base.md`. For each durable learning:

1. **Determine destination:** Which section of the base template should this live in? Code Standards, Execution Rules, Testing, Git & Commits, or Do NOT.
2. **Write it as a rule, not a learning entry.** Transform from observation ("we kept getting bitten by...") into directive ("Always do X when Y"). Match the tone and format of the existing rules in that section.
3. **Check for conflicts:** If the new rule contradicts an existing rule, surface it to the user. Don't silently overwrite.

After promoting, remove the promoted entries from each project's Compound Learnings section. They now live at the system level.

## Step 6: Prune Project Compound Learnings

For each project CLAUDE.md scanned:

1. **Remove promoted entries.** These now live in the base template.
2. **Consolidate duplicates** within the project.
3. **Archive stale entries** (older than 60 days, not promoted): move to a comment block at the bottom: `<!-- Archived: [entry] -->`
4. **Keep project-specific entries** that are genuinely only relevant to that one project (e.g., "this API has a 5-second timeout that looks like a failure").

Target: each project's Compound Learnings section stays under 15 entries after pruning.

## Step 7: Summary

Print a structured summary:
```
Retro complete.
Projects scanned: [N]
Learnings reviewed: [N]
Promoted to base template: [N] ([list sections updated])
Pruned from projects: [N]
Contradictions flagged: [N]
```

## Notes

- Run this from `30_Projects/`, not from inside a specific project.
- This is a periodic maintenance task, not an every-session step. Run it after a major feature ships, at the end of a sprint, or monthly.
- Never delete learnings without promoting or archiving them first.
- If a project has no Compound Learnings section, skip it silently.
- The base template is the institutional memory of the build system. Treat promotions with care: a bad rule in the base template affects every future project.
