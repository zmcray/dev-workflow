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
Human gate: [none | procedure: … | judgment: … — what a person must do and when: before build / mid-build / before merge]
```

Rules:

- **Grill before you write it.** A packet is produced by a `grilling` session (`skills/grilling`), run with `domain-modeling` so terms land in `CONCEPTS.md`. The session ends only when the frontier is empty: nothing left silently assumed. A packet written without one is a draft, not a contract.
- **Durable over precise.** The packet may sit in the queue for days. Describe interfaces, types, and behaviour, never file paths or line numbers (they rot); File scope is the one exception, and it names directories or globs, not lines. Say *what* the system should do, not *how* to edit the code.
- **Use the glossary.** Packet language is `CONCEPTS.md` vocabulary. A term that is not in the glossary yet gets added during grilling, not invented in the packet.

- **Every acceptance criterion is executable** — it names the test or screenshot check that proves it. If it can't be checked by a machine, rewrite it until it can, or it stays a day-shift issue.
- **Artboard is required for any UI work.** The approved canvas is implementation input; night agents diff their screenshots against it.
- **File scope is a fence, not a hint.** The building agent may not touch paths outside it. Wanting to = kick back with a Linear comment, don't expand.
- **Human gate is mandatory.** `none` means the chunk can finish overnight with nobody present. Anything else (a person judging images or screens, credentials / 2FA / App Store / vendor console, a physical device, a taste call, an outside party) gets named here and the issue carries `gate:human`; it never enters the night queue. Start the line with `procedure:` (clicking, copying, pasting only the person can do; it gets a wizard script) or `judgment:` (looking and deciding; it stays a checklist ask). If the human step can be its own small chunk, split it so the rest stays hands-off.
- **Out of scope is mandatory**, even when it feels obvious. It is what keeps an unattended agent from helpfully doing more.
- **Keep it a chunk.** Well under an hour of agent time, about 5 files and 300 changed lines or fewer, 1-4 acceptance checks. Bigger than that, split it. File scope that overlaps another queued chunk needs a `blocked by` edge; disjoint scope with no edge means the two may be built at the same time.
- Complexity (`tier:*`), routing (`lane:*`), and merge trust (`class:*`) are labels, never packet fields. The packet never names a model; `DISPATCH.md` maps tier to model at dispatch time. Dispatch decisions stay out of the spec.
