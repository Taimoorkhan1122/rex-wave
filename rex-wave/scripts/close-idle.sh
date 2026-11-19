#!/bin/sh
# usage: close-idle.sh <run-dir> [--dry-run] — closes finished reviewer tabs, and builder tabs whose latest verdict is APPROVE with no fix pending
set -u
here=$(cd "$(dirname "$0")" && pwd)
. "$here/lib.sh"
load_env "${1:?usage: close-idle.sh <run-dir> [--dry-run]}"
DRY=0; [ "${2:-}" = "--dry-run" ] && DRY=1

for t in $TASKS; do
  # reviewer tabs: close once the review process has exited
  if [ -f "$RUN/$t.reviewer.json" ] && grep -q '^REVIEW EXIT' "$RUN/$t.review.md" 2>/dev/null; then
    close_window "$RUN/$t.reviewer.json" "$RUN/$t.reviewer.closed"
  fi
  if [ -f "$RUN/$t.reviewer2.json" ] && grep -q '^REVIEW EXIT' "$RUN/$t.review2.md" 2>/dev/null; then
    close_window "$RUN/$t.reviewer2.json" "$RUN/$t.reviewer2.closed"
  fi

  # builder tab: done when the latest verdict is APPROVE and no fix round is waiting to be sent
  [ -f "$RUN/$t.builder.json" ] || continue
  latest="$RUN/$t.review.md"
  [ -f "$RUN/$t.reviewer2.json" ] && latest="$RUN/$t.review2.md"
  [ "$(verdict_of "$latest")" = "VERDICT: APPROVE" ] || continue
  if [ -f "$RUN/$t.fix.md" ] && [ ! -f "$RUN/$t.fixprev" ]; then continue; fi
  # stale verdict: new commits landed after the reviewed HEAD; leave the tab open
  if [ -f "$RUN/$t.reviewed-head" ]; then
    cur=$(head_of "$t")
    [ -n "$cur" ] && [ "$cur" != "$(cat "$RUN/$t.reviewed-head")" ] && continue
  fi
  close_window "$RUN/$t.builder.json" "$RUN/$t.builder.closed"
done
if [ "$DRY" = 1 ]; then printf 'close-idle: dry run done\n'; else printf 'close-idle: done\n'; fi
