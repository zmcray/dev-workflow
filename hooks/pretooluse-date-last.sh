#!/usr/bin/env bash
# PreToolUse hook: blocks a Write that would create a new date-first file.
# Editing or overwriting a file that already exists is allowed, so legacy names never block work.
GUARD="$(cd "$(dirname "$0")/.." && pwd)/scripts/guards/date-last-names.mjs"
exec node - "$GUARD" 3<&0 <<'NODE'
const fs = require('node:fs')
const path = require('node:path')
const { spawnSync } = require('node:child_process')
const payload = JSON.parse(fs.readFileSync(3, 'utf8'))
const file = payload.tool_input?.file_path
if (payload.tool_name !== 'Write' || typeof file !== 'string') process.exit(0)
const absolute = path.resolve(payload.cwd || process.cwd(), file)
if (fs.existsSync(absolute)) process.exit(0)
const result = spawnSync(process.execPath, [process.argv[2], '--paths', file], { encoding: 'utf8' })
if (result.status === 1) {
  process.stderr.write(result.stderr)
  process.exit(2)
}
process.exit(0)
NODE
