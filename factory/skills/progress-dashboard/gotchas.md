# Gotchas

- **The issue list overflows the tool result.** A 200-plus issue project comes back as a saved file, not inline. Pass that file path straight to `summarize.py`; do not try to read it into context.
- **Filtering by `updatedAt` drops old done issues** and makes phase totals wrong. Always pull the whole project and let `summarize.py` scope it.
- **Work that crosses epics.** An epic's starter content or seed import can live in another epic's milestone (Circuits starters sat in `Minimum dose 2`). Read the `Order:` lines and pass those IDs with `--extra`, or the dashboard under-reports the epic.
- **"In Progress" can hide unshipped work.** The night shift skips `started` issues, so a local-only branch stalls the whole chain behind it without any red signal. Always check branches for in-progress issues (Behaviour step 5).
- **Hardening dilutes the headline.** Hardening shelves often hold more open items than the live phases. Headline tiles use the live-milestone totals (`live_totals`); hardening gets its own row and tile.
- **An empty live milestone** (everything canceled or moved) shows 0 / 0. Render it as "Parked" or "Rescoped" with a note saying where the work went, never as a 0% bar.
