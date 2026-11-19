#!/bin/sh
# usage: run-agent.sh <run-dir> <task> — runs in the builder tab: execs interactive commandcode in the task worktree with common.md + brief
set -eu
run=${1:?usage: run-agent.sh <run-dir> <task>}
t=${2:?usage: run-agent.sh <run-dir> <task>}
. "$run/wave.env"
cd "$WT_ROOT/$t"
prompt=$(cat "$run/common.md" "$run/$t.md")
# interactive (not -p) so the user can watch the tab; --yolo is approved per wave, so the no-deploy rule is prompt-only
exec commandcode "$prompt" -t --yolo --skip-onboarding -m "$BUILDER_MODEL" -n "$t"
