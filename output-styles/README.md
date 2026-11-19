# Output styles

An output style is a prompt file that sets how Claude Code writes its replies.

`~/.claude/output-styles/exec-brief.md` is a symlink to `output-styles/exec-brief.md` in this folder, so the file is edited and reviewed here, not in `~/.claude`.

## Install

```
bash ~/Developer/dev-workflow/scripts/install-output-styles.sh
```

Add `--dry-run` to see what it would do. An existing plain file is moved aside as `exec-brief.backup-<HHMMSS>-<YYYY-MM-DD>.md`; nothing is deleted. `setup-factory-machine.sh` runs it too.

## The "Action needed" rule

A step goes to the human only if it needs one of these:

- his identity (a sign-in, a signature, an approval only he can give)
- his money
- a physical device
- a product judgment

Anything else the agent does itself, or reports as "I tried X, blocked by Y".
