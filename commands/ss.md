---
name: ss
description: Grab the N most recent screenshots from ~/Desktop/Screenshots and act on them
argument-hint: "[count] [action]"
---

# /ss — Screenshot in, action out

Zack talks to you visually by screenshotting. This command grabs the newest screenshot(s) from `/Users/zacharymcray/Desktop/Screenshots` and acts on them based on his instruction.

## Step 1: Parse `$ARGUMENTS`

Split on whitespace.

- If the first token is a positive integer → that's the **count**; the rest is the **action**.
- Otherwise → count = `1`; the whole argument string is the **action**.
- If `$ARGUMENTS` is empty → count = `1`, action = `"describe"` (default: explain what's in the screenshot).

Examples:
- `/ss` → count=1, action="describe"
- `/ss huh` → count=1, action="huh"
- `/ss fix` → count=1, action="fix"
- `/ss 3 make infographic plz` → count=3, action="make infographic plz"
- `/ss 4` → count=4, action="describe"

## Step 2: List screenshots newest → oldest

Run:

```bash
ls -t "/Users/zacharymcray/Desktop/Screenshots" 2>/dev/null | head -n {count}
```

If the folder is empty or missing, stop and tell Zack: `No screenshots found in ~/Desktop/Screenshots.`

Take the top `{count}` filenames. Build absolute paths by prefixing `/Users/zacharymcray/Desktop/Screenshots/`.

## Step 3: Read every screenshot

Use the Read tool on each absolute path so the images load into context. Read them in newest-to-oldest order. Do not skip any. Do not summarize before reading — you need to actually see them.

Briefly state which files you grabbed (filenames only, one line):
`Loaded: screenshot-1.png, screenshot-2.png, …`

## Step 4: Interpret the action

Match the action string against these intents. Be generous — partial matches count. If it's none of these, treat the action string as a direct instruction about what to do with the screenshots.

### `huh` / `what` / `explain` / `describe` / empty
Explain what's in the screenshot(s). If multiple, walk through each, then give a unified read of what they're collectively showing. Be specific about text, UI elements, data, and context. Don't be vague.

### `fix`
Zack has screenshotted a problem that needs fixing. Figure out the context:
- **Error message / stack trace / console output** → identify the root cause, locate the offending code in the current project, and edit it. Run tests if they exist. Don't just describe the fix — ship it.
- **Visual/design bug** (overlapping text, broken layout, wrong color, misaligned elements) → find the relevant component/CSS in the current project and fix it. Verify with a screenshot or dev server if one is running.
- **Data/config issue** → trace it back to the source file and correct it.

Don't ask "which file?" — search the codebase first. Only ask if truly ambiguous after searching.

### `do this` / `copy this` / `remix` / `steal this`
Zack saw someone do something smart online and wants to apply it to his work. Steps:
1. Extract the *mechanism* — what exactly is clever here? (format, hook, structure, tactic, visual, copy pattern)
2. Pull in Zack's context: read `/Users/zacharymcray/Documents/Work/00_Context/about-me.md`, `voice-and-style.md`, `McRayGroup.md`, and the thesis section of `CLAUDE.md`.
3. Remix it for Zack's goals — LMM PE, AI-native consulting, wealth management vertical, the Operator's Moment thesis. Match his voice (no em dashes, direct, no fluff).
4. Produce the actual artifact (post, outline, script, page, diagram), not a plan to produce it.

### `make infographic` / `infographic` / `visualize` / `diagram`
Synthesize the content of the screenshots into one unified visual. Generate production-ready HTML/CSS (or SVG if simpler) that could render as an infographic. Respect Zack's voice and style. Save to `/Users/zacharymcray/Documents/Work/30_Projects/` with a descriptive filename and give him the `computer://` link.

### `post` / `tweet` / `linkedin`
Turn the screenshot content into a draft social post in Zack's voice. Reference `voice-and-style.md` and `content-pillars.md`. No em dashes. Direct, actionable, no fluff.

### `note` / `save` / `capture`
Extract the key info from the screenshot and save it as a markdown note in the appropriate vault location. Ask only if the destination is ambiguous.

### Anything else
Treat the action string as a direct instruction. Example: `/ss summarize for my 9am` → read the screenshot and produce a meeting-ready summary. Use judgment.

## Step 5: Deliver

Output the result of the action. No preamble, no "I'll now…". Ship the finished thing. If you edited code or created files, list what changed with `computer://` links where applicable.

## Rules

- **Always act, never narrate.** Zack screenshots to skip typing — finish the loop.
- **Never ask "which screenshot did you mean?"** — you grabbed them by recency, trust the order.
- **Timezone is ET.** Dates in ET.
- **No em dashes.** Use commas, periods, semicolons, or "..." per `voice-and-style.md`.
- **Boil the ocean.** Per `CLAUDE.md` Standard of Work: ship the complete thing, not a plan to build it.
