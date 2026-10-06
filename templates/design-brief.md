# Design brief template

The handoff planning writes when it stops at "design first" (AGENTS.md > Spec gate). One brief per **group** (issues that change the same screens share one canvas). The reader is Zack, cold, in the morning: everything he needs to open Claude Design and finish is on this page. He should never have to open the plan, the issues, or DESIGN.md to know what to draw.

Where it goes: `docs/design/briefs/YYYY-MM-DD-<group-slug>.md` in the project repo, committed with the planning work. A one-line comment on every issue in the group points at it. The planning session prints the "Your steps" section in full, then stops and waits for `canvas <url>`.

Rules for the writer:

- **Name the group by what it is**, never "Canvas A". "Circuit workout screens", not a letter.
- **Every screen gets its own block** with what it must show, the primary action, the secondary actions, what happens next, the states to draw, and what is deliberately not there. Pull these from the issues' acceptance checks and the plan's requirements; write them as things a person can see on a screen.
- **Inline the design rules** the canvas needs (colors, type, spacing, component rules) from the repo's DESIGN.md, so the prompt stands alone.
- **Never ask Zack to attach files.** Every file the canvas needs (DESIGN.md, reference screenshots, existing canvases) lives in the repo: copy anything from outside into `docs/design/briefs/assets/<group-slug>/` and commit it with the brief. Merge to the default branch before handing off, then list each file in the prompt's "Reference files" block by its full GitHub URL on the default branch (`https://github.com/<owner>/<repo>/blob/main/<path>`), so Claude Design opens them itself. The table's "Reference files" row lists the same paths for humans.
- **Give example content** (exercise names, numbers, copy) so the mockups look real. Say it is illustrative.
- **Match the rung recipe** (MANUAL §2): directions only on `journey` (key screen) and `product` (magic screen); walk-through only on `journey` and `product`; `screens` gets the core screen's empty, loading and error states instead.
- **"Done when"** is a checklist Zack can tick by looking at the canvas. Each line traces to an issue's acceptance check.
- Plain words. No requirement IDs in the prompt (Claude Design does not know what R16a is); IDs may appear in "Done when" in brackets.

---

```markdown
# Design brief: <group name, plain words>

<One sentence: what these screens are for and why they need drawing before the build.>

| | |
|---|---|
| Issues | MCR-… <title> · MCR-… <title> |
| Rung | design:<rung> · about <time from the rung table> |
| Needed before | <the first issue or milestone that cannot build without this canvas> |
| Repo | <repo path> |
| Reference files | <DESIGN.md path> · <reference image paths> (all committed on main; the prompt links them) |

## Your steps

1. Open Claude Design and start a new project called "<Project> · <group name>".
2. Copy the whole "Prompt to paste" block below into Claude Design. It links every reference file; nothing to attach.
3. <journey/product only> Pick one of the directions for <key screen>. Tell Claude Design which one and why, in one line. It then draws the rest in that direction.
4. Go down "Done when" and tick each line by looking at the canvas. Ask Claude Design to fix anything missing.
5. <journey/product only> Walk through it once as the user: <one concrete scenario, start to finish>. Write down anything that confused you and fix it.
6. Copy the canvas share link. In the planning session, type `canvas <link>`.

## Prompt to paste

~~~
<App> is <one-line description>. Device: <device>. Fidelity: <wireframe | mid-fi using the design system in DESIGN.md below>.

Reference files (open each one before drawing):
- DESIGN.md, the design system: https://github.com/<owner>/<repo>/blob/main/DESIGN.md
- <what it shows>: https://github.com/<owner>/<repo>/blob/main/<path>

Design rules (from DESIGN.md):
- <5 to 10 rules that shape these screens: palette roles, type roles and sizes, spacing, radius, component rules, what is banned>

What we're drawing: <one paragraph on the feature in user terms>.

Example content (illustrative, not defaults):
- <realistic sample data>

<journey/product only> First, give me <2 to 4> different directions for the <key screen>, each on a named axis (<axis ideas>). Wait for my pick before drawing the rest.

Screens (one artboard each, left to right in this order):

1. <Screen name>
   - Must show: …
   - Primary action: …
   - Secondary actions: …
   - What happens next: …
   - States to draw: …
   - Not on this screen: …

2. …

Flow: put a note on every transition, "trigger → destination":
- …

Organize the canvas into pages: Flow (screens in order), States (the extra states), Shelf (anything we are parking). Every artboard gets one sticky note: primary action · secondary actions · what happens next · what data is shown · what is deliberately not here.

Out of scope for this canvas: <other groups' screens, parked features>.
~~~

## Done when

- [ ] <visible check> [MCR-…]
- [ ] …

## After you paste the link

The planning session adds `Canvas: <link>` to every issue above, posts the link on each, and picks planning back up where it stopped. Nothing else for you to do.
```
