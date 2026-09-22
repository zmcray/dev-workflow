# PRD template (Caspian v3 output contract)

Write to `docs/strategy/YYYY-MM-DD-<topic>-prd.md` in the repo, before any remote write. Firm-level (no repo): `~/Documents/Work/01-mcray-group/10-strategy/<theme>/`. Every section marked REQUIRED must be present or the run is not done. Use `CONCEPTS.md` vocabulary. No file paths, line numbers, or model names anywhere in the body.

```markdown
---
title: <product> <theme>
product: <repo name>
mode: NEW | EXPAND | REFRESH | PACKET
type: internal | external | hybrid
created: YYYY-MM-DD
version: 1
last_refreshed: YYYY-MM-DD        # REFRESH only
status: draft | approved | shipped | superseded
strategy_track: <track name from STRATEGY.md, or "none">
linear_initiative: <id>            # written by linear-write, verified after
linear_project: <id>
linear_issues: []                  # written by linear-write, verified after
author: Zachary McRay
---

## Change Log                       # EXPAND / REFRESH only
### YYYY-MM-DD ... <event>: <one line>

## Loop sentence [REQUIRED]
[user does X] → [magic Y appears]

## Appetite [REQUIRED]
<time budget for M1, e.g. "one weekend, ~6 chunks"> ... scope was cut to fit this, not estimated from it.

## Press release [REQUIRED]
<≤150 words, one customer quote, no feature list>

## Problem statement [REQUIRED]
<who, when, what hurts today, in the user's words>

## Strategic fit [REQUIRED]
<which STRATEGY.md track this serves and why now; one paragraph>

## M1: the skeleton [REQUIRED]
Every feature here breaks the loop sentence if removed. Sequence: `A → B → (C, D parallel)`. Dominant risk retired first: <risk> by <feature>.

### <Feature A>
- **Does:** <one sentence, user-visible>
- **Risks:** value <..> · usability <..> · feasibility <..> · viability <..>   ("untested" allowed)
- **Tier:** mechanical | moderate | judgment
- **Acceptance criteria:**
  - WHEN <trigger>, the system SHALL <behaviour>  (verified by: <test name or screenshot check>)
  - ...
- **Not here:** <what this feature deliberately does not do>

### <Feature B>
...

## Four-risk exit [REQUIRED]
| Risk | Retired by | In M1? |
|---|---|---|
| Value | <named test, usage gate, or "accepted: reason"> | yes/no |
| Usability | ... | |
| Feasibility | ... | |
| Viability | ... | |

## Success criteria [REQUIRED]
<3-5 measurable signals, each with the number and the date it is read>

## Kill conditions [REQUIRED]
<what would make us stop M1, stated before we start>

## Later Shelf [REQUIRED, may be empty with a reason]
| Feature | Defer reason | Kill condition | Re-price date |
|---|---|---|---|

## Out of scope [REQUIRED]
<what this PRD will never do, even if it is easy>

## Decision Log [REQUIRED]
| # | Decision | Chosen | Rejected | Reason | Source (lens / Red Team / Eng / founder) |
|---|---|---|---|---|---|
Held review findings are logged here too ("Red Team flagged X; held because Y").
```
