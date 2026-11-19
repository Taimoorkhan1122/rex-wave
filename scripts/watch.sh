#!/bin/sh
# usage: watch.sh [--notify] <run-dir> — run in background. One watcher for the wave:
# prints a ping per task the moment it is reviewable (REPORT-AGENT.md exists and HEAD is
# past BASE_SHA), and opens the reviewer tab for it. Exits when all reviewer tabs are open.
# --notify adds a bell + desktop-notification escape (terminal.app) per ping.
# Gives up after MAX_WAIT seconds (default 4h), naming the tasks whose builder never finished.
set -u
here=$(cd "$(dirname "$0")" && pwd)
. "$here/lib.sh"

NOTIFY=0
while [ $# -gt 0 ]; do
  case $1 in
    --notify) NOTIFY=1; shift ;;
    --) shift; break ;;
    -*) die "unknown option: $1 (usage: watch.sh [--notify] <run-dir>)" ;;
    *) break ;;
  esac
done
[ $# -ge 1 ] || die "usage: watch.sh [--notify] <run-dir>"
load_env "$1"

# reviewable <task>: REPORT-AGENT.md present and HEAD past BASE_SHA
reviewable() {
  wt=$(wt_of "$1"); h=$(head_of "$1")
  [ -f "$wt/REPORT-AGENT.md" ] && [ -n "$h" ] && [ "$h" != "$BASE_SHA" ]
}
# ping <task> <head>: bell + desktop-notification escape + line
ping() {
  if [ "$NOTIFY" = 1 ]; then printf '\a\033]9;rex-wave: %s done\007rex-wave: %s is reviewable (HEAD %s)\n' "$1" "$1" "$2"; else printf '%s is reviewable (HEAD %s)\n' "$1" "$2"; fi
}

pending=""
for t in $TASKS; do [ -f "$RUN/$t.reviewer.json" ] || pending="$pending $t"; done
# give up on tasks that never finish (builder died, report never written); MAX_WAIT seconds, default 4h
MAX_WAIT=${MAX_WAIT:-14400}
start=$(date +%s)
while [ -n "$pending" ]; do
  now=$(date +%s)
  if [ $((now - start)) -ge "$MAX_WAIT" ]; then
    if [ "$NOTIFY" = 1 ]; then
      printf '\a\033]9;rex-wave: %s gave up\007rex-wave: gave up after %ss, never reviewable:%s\n' "$LABEL" "$MAX_WAIT" "$pending"
    else
      printf '%s gave up after %ss, no REPORT-AGENT.md+commit for:%s\n' "$(date +%H:%M)" "$MAX_WAIT" "$pending" >&2
    fi
    exit 1
  fi
  next=""
  for t in $pending; do
    if reviewable "$t"; then
      h=$(head_of "$t")
      if open_tab "review-$t" "$(wt_of "$t")" "$RUN/$t.reviewer.json" "$here/review-agent.sh" "$RUN" "$t"; then
        printf '%s\n' "$h" > "$RUN/$t.reviewed-head"
        ping "$t" "$h"
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
  # cap the nap at the remaining wait so a short MAX_WAIT still gets a final scan
  if [ -n "$pending" ]; then
    left=$((MAX_WAIT - $(date +%s) + start))
    [ "$left" -gt 30 ] && left=30; [ "$left" -lt 1 ] && left=1
    sleep "$left"
  fi
done
if [ "$NOTIFY" = 1 ]; then
  printf '\a\033]9;rex-wave: %s complete\007rex-wave: all %s tasks reviewable\n' "$LABEL" "$LABEL"
else
  printf 'all reviews started\n'
fi
