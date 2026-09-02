# Build Packet (canonical template)

Lives in the Linear issue body. An issue without a complete packet never gets `night-eligible` and never enters the night queue. Copy this block:

```
## Build packet
Spec: [link to plan/PRD section, or inline]
Acceptance criteria:            # EARS-style; each maps to a test or screenshot check the agent can run
- WHEN [trigger], the system SHALL [behavior]   (verified by: [test name or screenshot check])
Artboard: [link to approved design canvas, or "n/a (no UI)"]
File scope: [paths this issue may touch]        # overlap with another queued issue = dependency edge, run sequentially
Out of scope: [what this issue deliberately does not do]
```

Rules:

- **Every acceptance criterion is executable** — it names the test or screenshot check that proves it. If it can't be checked by a machine, rewrite it until it can, or it stays a day-shift issue.
- **Artboard is required for any UI work.** The approved canvas is implementation input; night agents diff their screenshots against it.
- **File scope is a fence, not a hint.** The building agent may not touch paths outside it. Wanting to = kick back with a Linear comment, don't expand.
- **Out of scope is mandatory**, even when it feels obvious. It is what keeps an unattended agent from helpfully doing more.
- Routing (`lane:*`) and merge trust (`class:*`) are labels, never packet fields. Dispatch decisions stay out of the spec.
