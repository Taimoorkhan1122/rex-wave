#!/bin/sh
# usage: send-fix.sh <run-dir> <task> — types "read <fix.md> and apply" into an idle builder tab; records pre-fix HEAD in <task>.fixprev
set -u
here=$(cd "$(dirname "$0")" && pwd)
. "$here/lib.sh"
load_env "${1:?usage: send-fix.sh <run-dir> <task>}"
t=${2:?usage: send-fix.sh <run-dir> <task>}
is_task "$t" || die "unknown task: $t"
[ -f "$RUN/$t.fix.md" ] || die "write $RUN/$t.fix.md first (templates/fix.md)"
grep -q 'TODO' "$RUN/$t.fix.md" && die "fix.md still has TODO: $RUN/$t.fix.md"
[ -f "$RUN/$t.fixprev" ] && die "fix round already sent for $t"
blk=$(builder_blk "$t")
[ -n "$blk" ] && [ "$blk" != null ] || die "no builder block for $t (launch first)"

# ponytail: idle check matches the prompt UI string 'Ask your question'; if that string changes
# upstream, send-fix refuses (fail-safe) rather than misfires — update the string here. Upgrade
# path: a rex session-state query that reports block-busy status directly.
rex capture -s "$REX_SESSION" -b "$blk" --trim | tail -n 12 | grep -q 'Ask your question' || die "builder $t is not idle at its prompt; not sent"
rex send -s "$REX_SESSION" -b "$blk" "read $RUN/$t.fix.md and apply" || die "rex send failed for $t"
rex send-key -s "$REX_SESSION" -b "$blk" enter || die "rex send-key enter failed for $t"
head_of "$t" > "$RUN/$t.fixprev"
printf 'sent fix round 1 to %s (pre-fix HEAD %s)\n' "$t" "$(cat "$RUN/$t.fixprev")"
