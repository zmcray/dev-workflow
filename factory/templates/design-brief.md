# Design brief template

What planning writes when it meets a missing canvas (`rules/design.md` > Design brief). One brief per **group** (issues that change the same screens share one canvas). It has two readers: an agent running `/canvas`, possibly at night with nobody there, and Zack, cold, checking the result. Everything needed to draw and to judge the canvas is on this page. Neither should have to open the plan or the issues to know what to draw.

Where it goes: `docs/design/briefs/<group-slug>-YYYY-MM-DD.md` in the project repo, committed with the planning work. Every issue in the group gets `needs-canvas`, a `Brief: <path>` line and a one-line comment pointing at it. Planning then moves on to the next issue.

Rules for the writer:

- **Name the group by what it is**, never "Canvas A". "Circuit workout screens", not a letter.
- **Every screen gets its own block** with what it must show, the primary action, the secondary actions, what happens next, the states to draw, and what is deliberately not there. Pull these from the issues' acceptance checks and the plan's requirements; write them as things a person can see on a screen.
- **Inline the design rules** the canvas needs (colors, type, spacing, component rules) from the repo's DESIGN.md, so the brief stands alone.
- **Never ask Zack to attach files.** Every file the canvas needs (DESIGN.md, reference screenshots, existing canvases) lives in the repo: copy anything from outside into `docs/design/briefs/assets/<group-slug>/` and commit it with the brief. List each file in the "Reference files" block by its full GitHub URL on the default branch (`https://github.com/<owner>/<repo>/blob/main/<path>`). The table's "Reference files" row lists the same paths for humans.
- **Give example content** (exercise names, numbers, copy) so the mockups look real. Say it is illustrative.
- **Match the rung recipe** (MANUAL §2): directions only on `journey` (key screen) and `product` (magic screen); walk-through only on `journey` and `product`; `screens` gets the core screen's empty, loading and error states instead.
- **"Done when"** is a checklist Zack can tick by looking at the canvas. Each line traces to an issue's acceptance check.
- Plain words. No requirement IDs in "What to draw" (whoever draws does not know what R16a is); IDs may appear in "Done when" in brackets.

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
| Reference files | <DESIGN.md path> · <reference image paths> (all committed on main; linked below) |

## How to get the canvas

1. Run `/canvas <group name>`. It draws a first canvas from "What to draw" below and gives you the link. If you skip it, the night draws it (`design:screens` builds the same night; `design:journey` and `design:product` wait for you).
2. <journey/product only> Pick one of the directions for <key screen>, and say why in one line. The rest gets drawn in that direction.
3. Go down "Done when" and tick each line by looking at the canvas. Ask for anything missing to be fixed.
4. <journey/product only> Walk through it once as the user: <one concrete scenario, start to finish>. Write down anything that confused you and fix it.
5. Say you're happy. `/canvas` writes the link to every issue above.

## What to draw

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

<journey/product only> First, draw <2 to 4> different directions for the <key screen>, each on a named axis (<axis ideas>). Do not pick one. In a working session, wait for Zack's pick before drawing the rest.

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

## After the canvas exists

`/canvas` adds `Canvas: <link>` to every issue above, posts the link on each, and clears `needs-canvas`. Anything an agent drew alone also carries `canvas:agent` until you look at it.
```
