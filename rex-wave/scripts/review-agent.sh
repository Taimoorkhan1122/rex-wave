#!/bin/sh
# usage: review-agent.sh <run-dir> <task> — runs in reviewer tab: opencode cavecrew-reviewer on base..HEAD, output to <task>.review.md
set -u
here=$(cd "$(dirname "$0")" && pwd)
. "$here/lib.sh"
load_env "${1:?usage: review-agent.sh <run-dir> <task>}"
t=${2:?usage: review-agent.sh <run-dir> <task>}
wt=$(wt_of "$t"); cd "$wt" || die "no worktree $wt"

prompt="Review the commits on this branch since $BASE_SHA in this worktree ($wt). Get the diff with: git diff $BASE_SHA..HEAD (and git log $BASE_SHA..HEAD). Read changed files in full plus their callers where needed.
The task brief the author worked from is below. Check the diff does what it asks, nothing is broken, and there is no scope creep.
Focus first on: $REVIEW_FOCUS.
Also flag: any deploy, push or remote-DB command evidence, committed REPORT-AGENT.md, or stray files.
Do NOT edit files, commit, or run tests. Output findings only, one line each in your standard severity format, then a totals line and a final line: VERDICT: APPROVE or VERDICT: CHANGES REQUESTED.

--- BRIEF ---
$(cat "$RUN/$t.md")"

opencode run --agent cavecrew-reviewer -m "$REVIEW_MODEL" --auto --title "review-$t" "$prompt" 2>&1 | tee "$RUN/$t.review.md"
printf 'REVIEW EXIT\n' >> "$RUN/$t.review.md"
