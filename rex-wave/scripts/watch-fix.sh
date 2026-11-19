#!/bin/sh
# usage: watch-fix.sh <run-dir> — run in background. Opens a round-2 review tab per fixed task once HEAD moved and REPORT-AGENT.md has "## Fix round 1".
set -u
here=$(cd "$(dirname "$0")" && pwd)
. "$here/lib.sh"
load_env "${1:?usage: watch-fix.sh <run-dir>}"

pending=""
for t in $TASKS; do
  [ -f "$RUN/$t.fixprev" ] && [ ! -f "$RUN/$t.reviewer2.json" ] && pending="$pending $t"
done
# give up on tasks whose builder never moved; MAX_WAIT seconds, default 4h
MAX_WAIT=${MAX_WAIT:-14400}
start=$(date +%s)
while [ -n "$pending" ]; do
  now=$(date +%s)
  if [ $((now - start)) -ge "$MAX_WAIT" ]; then
    printf '%s gave up after %ss, no fix commit for:%s\n' "$(date +%H:%M)" "$MAX_WAIT" "$pending" >&2
    exit 1
  fi
  next=""
  for t in $pending; do
    wt=$(wt_of "$t"); prev=$(cat "$RUN/$t.fixprev"); h=$(head_of "$t")
    if [ -n "$h" ] && [ "$h" != "$prev" ] && grep -q '^## Fix round 1' "$wt/REPORT-AGENT.md" 2>/dev/null; then
      if open_tab "review2-$t" "$wt" "$RUN/$t.reviewer2.json" "$here/review2-agent.sh" "$RUN" "$t" "$prev"; then
        printf '%s round-2 review started: %s (%s..%s)\n' "$(date +%H:%M)" "$t" "$prev" "$h"
      else
        printf '%s round-2 tab failed for %s, retrying\n' "$(date +%H:%M)" "$t"
        next="$next $t"
      fi
    else
      next="$next $t"
    fi
  done
  pending=$next
  [ -n "$pending" ] && sleep 30
done
printf 'all round-2 reviews started\n'
