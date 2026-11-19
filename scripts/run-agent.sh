#!/bin/sh
# usage: run-agent.sh <run-dir> <task> — runs in the builder tab: execs the interactive builder agent in the task worktree with common.md + brief
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/lib.sh"
load_env "${1:?usage: run-agent.sh <run-dir> <task>}"
t=${2:?usage: run-agent.sh <run-dir> <task>}
cd "$WT_ROOT/$t"
prompt=$(mktemp)
cat "$RUN/common.md" "$RUN/$t.md" > "$prompt"
# interactive so the user can watch the tab; broad permissions are approved per wave, so the no-deploy rule is prompt-only
builder_run "$BUILDER_AGENT" "$BUILDER_MODEL" "$t" "$prompt"
