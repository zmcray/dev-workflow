#!/usr/bin/env python3
"""Count Linear issues for a progress dashboard.

Input: one or more files holding a Linear list_issues result (the MCP tool's JSON,
either {"issues": [...]} or a [{"text": "..."}] wrapper). Pass every page.

Scope:
  --scope project                 every milestone, grouped by epic
  --scope epic --name Circuits    milestones whose name starts with the epic prefix
  --scope milestone --name "Circuits 2"   one milestone (prefix match on the name)
  --extra MCR-1,MCR-2             pull extra issues into scope (cross-milestone links)
  --today YYYY-MM-DD              date for the closed-by-day window (default: today)

Output: JSON on stdout. Canceled and duplicate issues are left out of every total
and reported separately.
"""
import argparse
import datetime as dt
import json
import re
import sys
from collections import defaultdict

EPIC_RE = re.compile(r"^(?P<epic>.+?)(?:\s+(?P<n>\d+))?:\s*(?P<rest>.*)$")
DONE = {"completed"}
DROPPED = {"canceled", "duplicate"}
STARTED = {"started"}


def load(paths):
    issues = {}
    for p in paths:
        raw = json.load(open(p))
        if isinstance(raw, list) and raw and isinstance(raw[0], dict) and "text" in raw[0]:
            raw = json.loads(raw[0]["text"])
        for i in raw.get("issues", raw) if isinstance(raw, dict) else raw:
            issues[i["id"]] = i
    return list(issues.values())


def milestone_name(i):
    m = i.get("projectMilestone")
    return (m or {}).get("name") if isinstance(m, dict) else m


def labels(i):
    return [l if isinstance(l, str) else l.get("name", "") for l in (i.get("labels") or [])]


def parse_milestone(name):
    """Return (epic, kind, phase_number). kind is live | hardening | later | legacy | none."""
    if not name or name == "No milestone":
        return ("No milestone", "none", None)
    m = EPIC_RE.match(name)
    if not m:
        return ("Shipped earlier", "legacy", None)
    epic, n, rest = m.group("epic").strip(), m.group("n"), m.group("rest").strip().lower()
    if n is None and rest.startswith("hardening"):
        return (epic, "hardening", None)
    if n is None and (rest.startswith("later") or rest.startswith("deferred")):
        return (epic, "later", None)
    return (epic, "live", int(n) if n else None)


def status_bucket(i):
    t = (i.get("statusType") or "").lower()
    if t in DONE:
        return "done"
    if t in DROPPED:
        return "dropped"
    if t in STARTED:
        return "doing"
    return "todo"


def brief(i):
    return {
        "id": i["id"],
        "title": i.get("title", ""),
        "status": i.get("status"),
        "milestone": milestone_name(i),
        "labels": labels(i),
        "completedAt": (i.get("completedAt") or "")[:10] or None,
        "startedAt": (i.get("startedAt") or "")[:10] or None,
        "updatedAt": (i.get("updatedAt") or "")[:10] or None,
    }


def tally(items):
    c = defaultdict(int)
    for i in items:
        c[status_bucket(i)] += 1
    total = c["done"] + c["doing"] + c["todo"]
    return {
        "total": total,
        "done": c["done"],
        "doing": c["doing"],
        "todo": c["todo"],
        "dropped": c["dropped"],
        "pct_done": round(100 * c["done"] / total, 1) if total else 0.0,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("files", nargs="+")
    ap.add_argument("--scope", choices=["project", "epic", "milestone"], default="project")
    ap.add_argument("--name", default="")
    ap.add_argument("--extra", default="")
    ap.add_argument("--today", default=dt.date.today().isoformat())
    ap.add_argument("--days", type=int, default=7)
    a = ap.parse_args()

    issues = load(a.files)
    extra = {x.strip() for x in a.extra.split(",") if x.strip()}
    want = a.name.strip().lower()

    def in_scope(i):
        if i["id"] in extra:
            return True
        name = milestone_name(i) or ""
        if a.scope == "project":
            return True
        if a.scope == "epic":
            return parse_milestone(name)[0].lower() == want
        return name.lower().startswith(want)

    scoped = [i for i in issues if in_scope(i)]
    if not scoped:
        sys.exit(f"No issues matched scope={a.scope} name={a.name!r}. Check the name against the milestone list.")

    by_ms = defaultdict(list)
    for i in scoped:
        key = milestone_name(i) or "No milestone"
        if i["id"] in extra and a.scope != "project" and not in_scope_by_milestone(i, a.scope, want):
            key = "Linked from other milestones"
        by_ms[key].append(i)

    milestones = []
    for name, items in by_ms.items():
        epic, kind, n = parse_milestone(name) if name != "Linked from other milestones" else ("", "linked", None)
        milestones.append({
            "name": name, "epic": epic, "kind": kind, "phase": n, **tally(items),
            "doing_ids": [x["id"] for x in items if status_bucket(x) == "doing"],
        })
    kind_order = {"live": 0, "linked": 1, "hardening": 2, "later": 3, "legacy": 4, "none": 5}
    milestones.sort(key=lambda m: (m["epic"], kind_order.get(m["kind"], 9), m["phase"] or 0, m["name"]))

    epics = []
    if a.scope == "project":
        by_epic = defaultdict(list)
        for i in scoped:
            by_epic[parse_milestone(milestone_name(i))[0]].append(i)
        for epic, items in by_epic.items():
            live = [x for x in items if parse_milestone(milestone_name(x))[1] == "live"]
            last = max((x.get("completedAt") or x.get("updatedAt") or "" for x in items), default="")[:10]
            epics.append({"epic": epic, "all": tally(items), "live": tally(live), "last_activity": last,
                          "doing_ids": [x["id"] for x in items if status_bucket(x) == "doing"]})
        epics.sort(key=lambda e: e["last_activity"], reverse=True)

    today = dt.date.fromisoformat(a.today)
    since = today - dt.timedelta(days=a.days - 1)
    closed = defaultdict(list)
    for i in scoped:
        d = (i.get("completedAt") or "")[:10]
        if d and status_bucket(i) == "done" and since.isoformat() <= d <= today.isoformat():
            closed[d].append({"id": i["id"], "title": i.get("title", "")})
    closed_by_day = [{"date": d, "count": len(v), "issues": v} for d, v in sorted(closed.items())]

    open_items = [i for i in scoped if status_bucket(i) in ("doing", "todo")]
    out = {
        "scope": a.scope,
        "name": a.name,
        "today": a.today,
        "totals": tally(scoped),
        "live_totals": tally([i for i in scoped if parse_milestone(milestone_name(i))[1] == "live"]),
        "milestones": milestones,
        "epics": epics,
        "closed_by_day": closed_by_day,
        "closed_in_window": sum(d["count"] for d in closed_by_day),
        "in_progress": [brief(i) for i in scoped if status_bucket(i) == "doing"],
        "needs_human": [brief(i) for i in open_items if "gate:human" in labels(i)],
        "no_milestone": [i["id"] for i in open_items if not milestone_name(i)],
    }
    json.dump(out, sys.stdout, indent=1)
    print()


def in_scope_by_milestone(i, scope, want):
    name = (milestone_name(i) or "").lower()
    if scope == "epic":
        return parse_milestone(milestone_name(i))[0].lower() == want
    return name.startswith(want)


if __name__ == "__main__":
    main()
