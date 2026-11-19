#!/bin/sh
# usage: review2-agent.sh <run-dir> <task> <pre-fix-sha> — runs in reviewer tab: round-2 review of fix commits, checks off round-1 findings
set -u
here=$(cd "$(dirname "$0")" && pwd)
. "$here/lib.sh"
load_env "${1:?usage: review2-agent.sh <run-dir> <task> <pre-fix-sha>}"
t=${2:?usage: review2-agent.sh <run-dir> <task> <pre-fix-sha>}
prev=${3:?usage: review2-agent.sh <run-dir> <task> <pre-fix-sha>}
wt=$(wt_of "$t"); cd "$wt" || die "no worktree $wt"

prompt="Round 2 review. Fix commits on this branch: git diff $prev..HEAD. Full branch since base: git diff $BASE_SHA..HEAD. Read changed files in full plus callers where needed.
1) For EACH round-1 finding below, say fixed / not fixed / partially, with file:line.
2) Then list any NEW problems the fix commits introduced. Focus first on: $REVIEW_FOCUS.
Do NOT edit files, commit, or run tests. Standard one-line severity format, a totals line, and a final line: VERDICT: APPROVE or VERDICT: CHANGES REQUESTED.

--- FIX BRIEF GIVEN TO AUTHOR ---
$(cat "$RUN/$t.fix.md")

--- ROUND-1 REVIEW ---
$(cat "$RUN/$t.review.md")"

reviewer_run "$REVIEW_AGENT" "$REVIEW_MODEL" "review2-$t" "$prompt" "$RUN/$t.review2.md"
