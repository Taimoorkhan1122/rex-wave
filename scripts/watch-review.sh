#!/bin/sh
# usage: watch-review.sh <run-dir> — run in background. Opens a reviewer tab per task once REPORT-AGENT.md exists and HEAD is past BASE_SHA. Exits when all are open.
set -u
here=$(cd "$(dirname "$0")" && pwd)
. "$here/lib.sh"
load_env "${1:?usage: watch-review.sh <run-dir>}"

pending=""
for t in $TASKS; do [ -f "$RUN/$t.reviewer.json" ] || pending="$pending $t"; done
# give up on tasks that never finish (builder died, report never written); MAX_WAIT seconds, default 4h
MAX_WAIT=${MAX_WAIT:-14400}
start=$(date +%s)
while [ -n "$pending" ]; do
  now=$(date +%s)
  if [ $((now - start)) -ge "$MAX_WAIT" ]; then
    printf '%s gave up after %ss, no REPORT-AGENT.md+commit for:%s\n' "$(date +%H:%M)" "$MAX_WAIT" "$pending" >&2
    exit 1
  fi
  next=""
  for t in $pending; do
    wt=$(wt_of "$t"); h=$(head_of "$t")
    if [ -f "$wt/REPORT-AGENT.md" ] && [ -n "$h" ] && [ "$h" != "$BASE_SHA" ]; then
      if open_tab "review-$t" "$wt" "$RUN/$t.reviewer.json" "$here/review-agent.sh" "$RUN" "$t"; then
        printf '%s\n' "$h" > "$RUN/$t.reviewed-head"
        printf '%s review started: %s (%s), tab %s\n' "$(date +%H:%M)" "$t" "$h" "$(tab_no "$(json_field "$RUN/$t.reviewer.json" '.window_id')")"
      else
        printf '%s review tab failed for %s, retrying\n' "$(date +%H:%M)" "$t"
        next="$next $t"
      fi
    else
      next="$next $t"
    fi
  done
  pending=$next
  [ -n "$pending" ] && sleep 30
done
printf 'all reviews started\n'
