# Agent pitfall measurement

Reruns the numbers from the 2026-10-16 pitfall study (`docs/plans/agent-friendly-codebase-2026-10-16.md`) so each fix can be judged by whether the mistakes it targets stop.

```bash
bash ~/Developer/dev-workflow/scripts/agent-pitfalls/run.sh 30
```

- `extract_messages.py` pulls Zack's typed messages from Claude Code, Cursor and Codex transcripts.
- `metrics.mjs` computes the deterministic numbers: commits, agent share, fix-subject share, date-first file adds, and the share of agent replies with "Action needed".
- `baseline-2026-10-16.json` holds the baseline counts. It holds no quotes or transcript text.
- `classify-prompt.md` is the one agent pass, needed only for the judged numbers (corrections and hand-backs per 100 messages).

Everything a run writes goes to `.local/agent-pitfalls-<days>d-<date>/`. That folder is git-ignored, because transcripts and Zack's words never go in this public repo.
