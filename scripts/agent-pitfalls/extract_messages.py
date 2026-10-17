"""Extract Zack's typed messages from Claude Code, Cursor and Codex transcripts for the 10 repos.

usage: python3 -I extract_messages.py --out <dir> [--days 92]
Writes one JSONL per repo: {repo, src, session, ts, prev_assistant, text}.
The output holds private words, so it goes under .local/ and never into git.
"""
import argparse, json, os, re, sys, glob, time
from pathlib import Path

HOME = Path.home()
ARGS = argparse.ArgumentParser()
ARGS.add_argument("--out", required=True)
ARGS.add_argument("--days", type=int, default=92)
OPTS = ARGS.parse_args()
OUT_DIR = Path(OPTS.out)
SINCE = time.time() - OPTS.days * 86400
REPOS = ["pulse-ios", "pulse", "motus", "saidso", "telos", "argus", "sonar", "quoting", "dev-workflow", "mcray-os-skills"]
NOISE = re.compile(r"^\s*(<command-|<local-command|<scheduled-task|<task-notification|<side-sessions-event|<ci-monitor-event|Caveat:|\[Request interrupted|# AGENTS\.md instructions|<environment_context>|<user_instructions>|Base directory for this skill|This session is being continued|<codex_internal_context|Background \(from the sess|Last login:|zacharymcray@)", re.S)

def repo_for_path(p: str):
    p = p.replace("/", "-")
    m = re.search(r"Developer-([A-Za-z0-9-]+)", p)
    if not m:
        return None
    rest = m.group(1).lower()
    for r in REPOS:  # pulse-ios before pulse
        if rest == r or rest.startswith(r + "-"):
            return r
    return None

def clean(t: str) -> str:
    t = re.sub(r"<system-reminder>.*?</system-reminder>", "", t, flags=re.S)
    t = re.sub(r"<timestamp>.*?</timestamp>", "", t, flags=re.S)
    m = re.search(r"<user_query>(.*?)</user_query>", t, flags=re.S)
    if m:
        t = m.group(1)
    return t.strip()

def texts(content):
    if isinstance(content, str):
        return [content]
    out = []
    for b in content or []:
        if isinstance(b, dict) and b.get("type") in ("text", "input_text"):
            out.append(b.get("text", ""))
    return out

def emit(writers, repo, src, session, ts, prev, text):
    text = clean(text)
    if not text or NOISE.match(text) or len(text) < 12:
        return
    if repo not in writers:
        writers[repo] = open(OUT_DIR / f"{repo}.jsonl", "w")
    w = writers[repo]
    w.write(json.dumps({"repo": repo, "src": src, "session": session, "ts": ts, "prev_assistant": prev[-500:], "text": text[:2500]}) + "\n")

def claude_code(writers):
    for d in (HOME / ".claude/projects").iterdir():
        repo = repo_for_path(d.name)
        if not repo:
            continue
        for f in d.glob("*.jsonl"):
            if f.stat().st_mtime < SINCE:
                continue
            prev, first = "", True
            for line in open(f, errors="ignore"):
                try:
                    o = json.loads(line)
                except Exception:
                    continue
                if o.get("isSidechain") or o.get("isMeta"):
                    continue
                msg = o.get("message") or {}
                if o.get("type") == "assistant":
                    t = " ".join(texts(msg.get("content")))
                    if t.strip():
                        prev = t
                elif o.get("type") == "user":
                    c = msg.get("content")
                    if isinstance(c, list) and any(isinstance(b, dict) and b.get("type") == "tool_result" for b in c):
                        continue
                    for t in texts(c):
                        if first and t.startswith("<scheduled-task"):
                            break
                        emit(writers, repo, "claude", f.stem, o.get("timestamp", ""), prev, t)
                    first = False

def cursor(writers):
    for f in glob.glob(str(HOME / ".cursor/projects/*/agent-transcripts/*/*.jsonl")):
        repo = repo_for_path(f.split("/projects/")[1].split("/")[0])
        if not repo or os.path.getmtime(f) < SINCE:
            continue
        prev = ""
        for line in open(f, errors="ignore"):
            try:
                o = json.loads(line)
            except Exception:
                continue
            ts = ""
            for t in texts((o.get("message") or {}).get("content")):
                if o.get("role") == "assistant":
                    prev = t
                elif o.get("role") == "user":
                    m = re.search(r"<timestamp>(.*?)</timestamp>", t)
                    emit(writers, repo, "cursor", Path(f).stem, m.group(1) if m else ts, prev, t)

def codex(writers):
    for f in glob.glob(str(HOME / ".codex/sessions/**/*.jsonl"), recursive=True):
        if os.path.getmtime(f) < SINCE:
            continue
        repo, prev = None, ""
        for line in open(f, errors="ignore"):
            try:
                o = json.loads(line)
            except Exception:
                continue
            p = o.get("payload") or {}
            if o.get("type") == "session_meta":
                repo = None if p.get("parent_thread_id") else repo_for_path(p.get("cwd", ""))
                if not repo:
                    break
            elif o.get("type") == "response_item" and p.get("type") == "message" and repo:
                t = " ".join(texts(p.get("content")))
                if p.get("role") == "assistant":
                    prev = t
                elif p.get("role") == "user":
                    emit(writers, repo, "codex", Path(f).stem, o.get("timestamp", ""), prev, t)

if __name__ == "__main__":
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    writers = {}
    claude_code(writers); cursor(writers); codex(writers)
    for w in writers.values():
        w.close()
    for r in REPOS:
        p = OUT_DIR / f"{r}.jsonl"
        n = sum(1 for _ in open(p)) if p.exists() else 0
        print(r, n)
