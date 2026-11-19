#!/bin/sh
# usage: finish.sh <run-dir> [--dry-run] [--keep-run] — teardown after the user merged.
# For each task: requires fix/<task> merged into BASE, clean worktree, REPORT-AGENT.md present.
# Then: removes the worktree, deletes the branch, prunes; finally removes the run dir (unless --keep-run).
# Refuses before touching anything if any task fails a check. Use --dry-run to preview.
set -u
here=$(cd "$(dirname "$0")" && pwd)
. "$here/lib.sh"
load_env "${1:?usage: finish.sh <run-dir> [--dry-run] [--keep-run]}"
DRY=0; KEEP_RUN=0
shift # run-dir already consumed by load_env
for arg in "$@"; do
  case $arg in
    --dry-run) DRY=1 ;;
    --keep-run) KEEP_RUN=1 ;;
    *) die "unknown argument: $arg (usage: finish.sh <run-dir> [--dry-run] [--keep-run])" ;;
  esac
done
command -v git >/dev/null || die "git not found"

# pass 1: check every task before removing anything
bad=""
for t in $TASKS; do
  wt=$(wt_of "$t")
  if [ ! -d "$wt" ]; then printf 'skip %s: no worktree (already removed?)\n' "$t"; continue; fi
  if ! git -C "$REPO" merge-base --is-ancestor "fix/$t" "$BASE" 2>/dev/null; then
    printf 'BLOCKED %s: branch fix/%s is not merged into %s\n' "$t" "$t" "$BASE"
    bad="$bad $t"; continue
  fi
  d=$(dirty_of "$t")
  if [ "$d" != 0 ]; then
    printf 'BLOCKED %s: %s uncommitted file(s) in worktree\n' "$t" "$d"
    bad="$bad $t"; continue
  fi
  [ -f "$wt/REPORT-AGENT.md" ] || printf 'warn %s: no REPORT-AGENT.md (removing worktree anyway — it was never committed)\n' "$t"
  if [ "$DRY" = 1 ]; then
    printf 'would remove: worktree %s, branch fix/%s, tab %s\n' "$wt" "$t" "$(json_field "$RUN/$t.builder.json" '.window_id' 2>/dev/null || echo '?')"
  fi
done
[ -z "$bad" ] || die "refusing to tear down; fix the BLOCKED tasks above (nothing was removed)"

# pass 2: teardown
for t in $TASKS; do
  wt=$(wt_of "$t")
  [ -d "$wt" ] || continue
  # close the builder tab if still open (guarded: marker prevents double-close)
  if [ -f "$RUN/$t.builder.json" ]; then
    close_window "$RUN/$t.builder.json" "$RUN/$t.builder.closed"
    if [ "${DRY:-0}" != 1 ] && [ ! -f "$RUN/$t.builder.closed" ]; then
      printf 'warn %s: builder tab close failed (rex unreachable?); removing worktree anyway\n' "$t"
    fi
  fi
  if [ "$DRY" = 1 ]; then
    printf 'would run: git -C %s worktree remove %s; branch -d fix/%s\n' "$REPO" "$wt" "$t"
  else
    # the uncommitted REPORT-AGENT.md is throwaway (hard rule: never committed); git worktree
    # remove refuses on any untracked file, so delete it first
    rm -f "$wt/REPORT-AGENT.md"
    git -C "$REPO" worktree remove "$wt" || die "worktree remove failed for $t (dirty? blocked earlier — investigate)"
    git -C "$REPO" branch -d "fix/$t" || die "branch delete failed for fix/$t"
  fi
done
[ "$DRY" = 1 ] || git -C "$REPO" worktree prune

# pass 3: run dir
if [ "$KEEP_RUN" = 1 ] || [ "$DRY" = 1 ]; then
  [ "$DRY" = 1 ] && [ "$KEEP_RUN" != 1 ] && printf 'would remove run dir %s\n' "$RUN"
  printf 'run dir kept: %s\n' "$RUN"
else
  rm -rf "$RUN" && printf 'run dir removed: %s\n' "$RUN"
fi
[ "$DRY" = 1 ] && printf 'finish: dry run done, nothing removed\n' || printf 'finish: wave torn down\n'
