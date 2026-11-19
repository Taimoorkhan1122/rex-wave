#!/bin/sh
# usage: launch.sh <run-dir> <task> — opens the interactive builder tab for one task (refuses if brief has TODO or builder already launched)
set -u
here=$(cd "$(dirname "$0")" && pwd)
. "$here/lib.sh"
load_env "${1:?usage: launch.sh <run-dir> <task>}"
t=${2:?usage: launch.sh <run-dir> <task>}
is_task "$t" || die "unknown task: $t"
[ -f "$RUN/$t.md" ] || die "no brief: $RUN/$t.md"
grep -q 'TODO' "$RUN/$t.md" && die "brief still has TODO: $RUN/$t.md"
[ -f "$RUN/$t.builder.json" ] && die "builder already launched for $t (see $RUN/$t.builder.json)"
[ -d "$(wt_of "$t")" ] || die "missing worktree: $(wt_of "$t")"

open_tab "$t" "$(wt_of "$t")" "$RUN/$t.builder.json" "$here/run-agent.sh" "$RUN" "$t" || die "rex window new failed for $t (check: rex window ls -s $REX_SESSION)"
win=$(builder_win "$t")
printf 'builder %s: tab %s (window %s, block %s)\n' "$t" "$(tab_no "$win")" "$win" "$(builder_blk "$t")"
