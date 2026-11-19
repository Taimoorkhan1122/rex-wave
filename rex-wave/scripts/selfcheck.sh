#!/bin/sh
# usage: selfcheck.sh — assert-based check of lib.sh state logic. No rex or git needed; needs jq and grep.
# Run after any lib.sh change: sh scripts/selfcheck.sh
set -u
here=$(cd "$(dirname "$0")" && pwd)
. "$here/lib.sh"
fails=0
ok() { printf 'ok: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; fails=$((fails+1)); }
eq() { if [ "$1" = "$2" ]; then ok "$3"; else fail "$3 (got [$1], want [$2])"; fi; }
RUN=$(mktemp -d "${TMPDIR:-/tmp}/rex-wave-selfcheck.XXXXXX")
trap 'rm -rf "$RUN"' EXIT
TASKS="T310 T312"
printf 'LABEL=selfcheck\nREPO=/tmp/nowhere\nBASE=main\nBASE_SHA=abc1234\n' > "$RUN/wave.env"

# is_task: membership and miss
eq "$(is_task T310 && echo y || echo n)" y "is_task finds member"
eq "$(is_task T999 && echo y || echo n)" n "is_task rejects non-member"

# verdict_of: last line wins, trailing spaces stripped, absent -> empty
printf 'VERDICT: APPROVE\n' > "$RUN/v1"
eq "$(verdict_of "$RUN/v1")" "VERDICT: APPROVE" "verdict single"
printf 'VERDICT: APPROVE\nmid text\nVERDICT: CHANGES REQUESTED\n' > "$RUN/v2"
eq "$(verdict_of "$RUN/v2")" "VERDICT: CHANGES REQUESTED" "verdict last wins"
printf 'VERDICT: APPROVE   \n' > "$RUN/v3"
eq "$(verdict_of "$RUN/v3")" "VERDICT: APPROVE" "verdict trailing spaces"
eq "$(verdict_of "$RUN/missing")" "" "verdict missing file"
printf 'no verdict here\n' > "$RUN/v4"
eq "$(verdict_of "$RUN/v4")" "" "verdict absent"

# review_state: not launched / running / exited-with-verdict / exited-no-verdict
printf '{"window_id":"w1","block_ids":["b1"]}\n' > "$RUN/T310.builder.json"
eq "$(review_state "$RUN/nofile.json" "$RUN/x.md")" "-" "state not launched"
printf 'REVIEW EXIT\n' > "$RUN/exited"
eq "$(review_state "$RUN/T310.builder.json" "$RUN/missing.md")" "running" "state running: no exit marker"
printf 'VERDICT: APPROVE\nREVIEW EXIT\n' > "$RUN/ok.md"
eq "$(review_state "$RUN/T310.builder.json" "$RUN/ok.md")" "VERDICT: APPROVE" "state exited with verdict"
printf 'REVIEW EXIT\n' > "$RUN/noV.md"
eq "$(review_state "$RUN/T310.builder.json" "$RUN/noV.md")" "no verdict" "state exited without verdict"

# json_field via fixture json (created above for review_state)
eq "$(builder_win T310)" "w1" "window_id read"
eq "$(builder_blk T310)" "b1" "block read"

# close_window: marker present = no-op; dry-run never closes
rm -f "$RUN/b.closed"
DRY=1 close_window "$RUN/T310.builder.json" "$RUN/b.closed" >/dev/null
[ -f "$RUN/b.closed" ] && fail "dry-run created marker" || ok "dry-run closes nothing"

# tab_no with empty id returns 0 silently
eq "$(tab_no "")" "" "tab_no empty id"

[ "$fails" = 0 ] && printf 'selfcheck: all passed\n' || { printf 'selfcheck: %d failure(s)\n' "$fails" >&2; exit 1; }
