# Forked skills

These four skills are forked from [mattpocock/skills](https://github.com/mattpocock/skills) (MIT) and adapted to the factory: Linear as the tracker, the build packet as the spec source, McRay Group labels. They are owned here and amended by the Learn phase like any other template; upstream updates are not pulled automatically.

| Skill | Upstream path | Role in the factory |
|---|---|---|
| `grilling` | `skills/productivity/grilling` | Decompose gate: interview until every packet question is answered |
| `domain-modeling` | `skills/engineering/domain-modeling` | Maintains `CONCEPTS.md` glossary + `docs/adr/` in every wired repo |
| `code-review` | `skills/engineering/code-review` | Verification ladder step 2: Standards vs Spec (packet) in parallel subagents |
| `wizard` | `skills/engineering/wizard` | Human-only steps: secrets, dashboards, App Store Connect, cutovers |

Forked at upstream commit `3cca18b368ae95cdbdebbff572ccafa662551015` (2026-09-09). The agent-brief durability rules from `skills/engineering/triage/AGENT-BRIEF.md` were folded into `templates/build-packet.md` rather than forked.

Back-port check: during the monthly platform-primitive audit (D-015), diff the four upstream paths against this commit and pull anything worth having:

```bash
git clone -q --depth 50 https://github.com/mattpocock/skills.git /tmp/mp && cd /tmp/mp && git diff 3cca18b3 -- skills/productivity/grilling skills/engineering/domain-modeling skills/engineering/code-review skills/engineering/wizard
```

Deploy: `wizard` ships with `dev-workflow/deploy-skills.sh` to Claude Code (`~/.claude/skills/`), Codex (`~/.agents/skills/`) and Cursor (`~/.cursor/skills/`), and the daily skill sync keeps it current on every factory Mac. The other three are still copied by hand to `~/.claude/skills/<name>`. `dev-workflow/deploy-agents-md.sh` warns on drift between source and deployed copies.
