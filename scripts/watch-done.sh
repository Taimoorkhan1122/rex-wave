#!/bin/sh
# usage: watch-done.sh <run-dir> — run in background from the block that wants pings.
# Prints one line + bell per task as soon as it is reviewable (REPORT-AGENT.md exists and
# HEAD is past BASE_SHA — the same condition watch-review.sh uses), then exits.
# The invoker sees the lines live in their own terminal; no polling status needed.
set -u
here=$(cd "$(dirname "$0")" && pwd)
. "$here/lib.sh"
load_env "${1:?usage: watch-done.sh <run-dir>}"

MAX_WAIT=${MAX_WAIT:-14400}
start=$(date +%s)
pending=""
for t in $TASKS; do pending="$pending $t"; done
while [ -n "$pending" ]; do
  now=$(date +%s)
  if [ $((now - start)) -ge "$MAX_WAIT" ]; then
    printf '\a\033]9;rex-wave: %s gave up after %ss\007rex-wave: gave up after %ss, never reviewable:%s\n' "$LABEL" "$MAX_WAIT" "$MAX_WAIT" "$pending"
    exit 1
  fi
  next=""
  for t in $pending; do
    wt=$(wt_of "$t"); h=$(head_of "$t")
    if [ -f "$wt/REPORT-AGENT.md" ] && [ -n "$h" ] && [ "$h" != "$BASE_SHA" ]; then
      printf '\a\033]9;rex-wave: %s done\007rex-wave: %s is reviewable (HEAD %s)\n' "$t" "$t" "$h"
    else
      next="$next $t"
    fi
  done
  pending=$next
  # cap the nap at the remaining wait so a short MAX_WAIT still gets a final scan
  if [ -n "$pending" ]; then
    left=$((MAX_WAIT - $(date +%s) + start))
    [ "$left" -gt 30 ] && left=30; [ "$left" -lt 1 ] && left=1
    sleep "$left"
  fi
done
printf 'rex-wave: all %s tasks reviewable\n' "$LABEL"
