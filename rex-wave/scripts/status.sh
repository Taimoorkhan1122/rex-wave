#!/bin/sh
# usage: status.sh <run-dir> — one line per task: commits since base, dirty files, report, review, fix, round-2 review
set -u
here=$(cd "$(dirname "$0")" && pwd)
. "$here/lib.sh"
load_env "${1:?usage: status.sh <run-dir>}"

printf '%-24s %-7s %-6s %-6s %-9s %-10s %-6s %s\n' task commits dirty report review fix stale review2
for t in $TASKS; do
  wt=$(wt_of "$t")
  if [ ! -d "$wt" ]; then printf '%-24s missing worktree\n' "$t"; continue; fi
  commits=$(git -C "$wt" rev-list --count "$BASE_SHA..HEAD" 2>/dev/null || printf '?')
  dirty=$(git -C "$wt" status --porcelain -- ':!REPORT-AGENT.md' 2>/dev/null | wc -l | tr -d ' ')
  if [ -f "$wt/REPORT-AGENT.md" ]; then report=yes; else report=no; fi
  if [ -f "$RUN/$t.fixprev" ]; then fix=sent
  elif [ -f "$RUN/$t.fix.md" ]; then fix=drafted
  else fix=-; fi
  review=$(review_state "$RUN/$t.reviewer.json" "$RUN/$t.review.md")
  review2=$(review_state "$RUN/$t.reviewer2.json" "$RUN/$t.review2.md")
  # stale: new commits landed after the reviewed HEAD (review covers an older branch)
  stale=-
  if [ -f "$RUN/$t.reviewed-head" ]; then
    cur=$(head_of "$t")
    [ -n "$cur" ] && [ "$cur" != "$(cat "$RUN/$t.reviewed-head")" ] && stale=yes
  fi
  printf '%-24s %-7s %-6s %-6s %-9s %-10s %-6s %s\n' "$t" "$commits" "$dirty" "$report" "$fix" "$review" "$stale" "$review2"
done
