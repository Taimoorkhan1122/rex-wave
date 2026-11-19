#!/bin/sh
# usage: run.sh — behavioral e2e for rex-wave claims (see docs/CLAIMS.md). Hermetic:
# stub rex + agent CLIs on PATH, no network. Needs git and jq.
set -u
here=$(cd "$(dirname "$0")" && pwd)
root=$(dirname "$here")
fails=0
n=0
ok() { printf 'ok: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; fails=$((fails+1)); }
eq() { if [ "$1" = "$2" ]; then ok "$3"; else fail "$3 (got [$1], want [$2])"; fi; }
has() { if printf '%s\n' "$2" | grep -qE -- "$1"; then ok "$3"; else fail "$3 (missing [$1])"; fi; }

tmp=${TMPDIR:-/tmp}; tmp=${tmp%/}
# fast, isolated PATH: stubs first (rex, agent CLIs, instant sleep), then real tools
ST=$tmp/rwe2e-stub.$$
rm -rf "$ST"; mkdir -p "$ST/bin"
ln "$here/stubs/agent" "$ST/bin/commandcode"; ln "$here/stubs/agent" "$ST/bin/claude"
ln "$here/stubs/agent" "$ST/bin/codex";      ln "$here/stubs/agent" "$ST/bin/opencode"
ln "$here/stubs/rex" "$ST/bin/rex";          ln "$here/stubs/sleep" "$ST/bin/sleep"
PATH="$ST/bin:$PATH"
export REX_STUB_STATE=$ST
REX_SESSION=sess-e2e

# new_repo: a git repo with one commit; echoes its path
new_repo() {
  d=$(mktemp -d "$tmp/rwe2e-repo.XXXXXX")
  git -C "$d" init -q -b main
  git -C "$d" -c user.email=t@t -c user.name=t commit -q --allow-empty -m base
  git -C "$d" config user.email t@t; git -C "$d" config user.name t
  printf '%s\n' "$d"
}

# new_run <repo> <label> [extra-manifest-lines...]: manifest -> init-wave -> echoes run dir + manifest path (two lines)
new_run() {
  _repo=$1; _label=$2; shift 2
  _m=$(mktemp "$tmp/rwe2e-man.XXXXXX")
  {
    printf 'LABEL=%s\n' "$_label"
    printf 'REPO=%s\n' "$_repo"
    printf 'BASE=main\n'
    printf 'TASKS="T1 T2"\n'
    printf 'BUILDER_MODEL=m\nREVIEW_MODEL=m\nCOAUTHOR="T <t@t>"\n'
    printf 'TYPECHECK_CMD=true\nTEST_CMD=true\nREVIEW_FOCUS=correctness\n'
    for l in "$@"; do printf '%s\n' "$l"; done
  } | awk -F= '!seen[$1]++{lines[NR]=$0; keys[$1]=NR; next} {lines[keys[$1]]=$0} END{for(i=1;i<=NR;i++) if(i in lines) print lines[i]}' > "$_m"
  sh "$root/scripts/init-wave.sh" "$_m" >/dev/null 2>&1 || { fail "init-wave (fixture $_label)"; printf 'x\n'; return 1; }
  printf '%s/rex-wave-%s\n' "$tmp" "$_label"
}

# full_briefs <run>: replace TODO in every brief stub so launch passes its gate
full_briefs() {
  for t in $(grep '^TASKS=' "$1/wave.env" | cut -d= -f2 | tr -d '"'); do
    sed 's/TODO/done/g' "$1/$t.md" > "$1/$t.md.new" && mv "$1/$t.md.new" "$1/$t.md"
  done
}

# fake_done <run> <task>: simulate a finished builder — a commit + REPORT-AGENT.md untracked
fake_done() {
  wt=$(cd "$1" && . ./wave.env && printf '%s/%s' "$WT_ROOT" "$2")
  printf 'report\n' > "$wt/REPORT-AGENT.md"
  git -C "$wt" commit -q --allow-empty -m "work $2"
}

wt_of_run() { (cd "$1" && . ./wave.env && printf '%s/%s' "$WT_ROOT" "$2"); }

trap 'rm -rf "$ST"' EXIT

## 1 — C3/C2: init creates worktrees on fix/<task>, run dir, brief stubs, default agents
repo=$(new_repo)
r=$(new_run "$repo" s1)
eq "$(git -C "$repo" worktree list | grep -c 'fix/T[12]')" 2 "init: two worktrees created"
[ -f "$r/wave.env" ] && [ -f "$r/common.md" ] && [ -f "$r/T1.md" ] && [ -f "$r/T2.md" ] \
  && ok "init: wave.env, common.md, brief stubs" || fail "init: run dir contents"
grep -q '^BUILDER_AGENT=commandcode' "$r/wave.env" && grep -q '^REVIEW_AGENT=opencode' "$r/wave.env" \
  && ok "init: default agents persisted" || fail "init: default agents"
rm -rf "$r" "$repo" "${repo}-worktrees"

## 2 — C4/C5: init refuses overwrite and bad agents
repo=$(new_repo)
r=$(new_run "$repo" s2)
# re-init the SAME label: copy the manifest to a new name (same LABEL/repo) so the
# second init-wave run hits the existing run dir / worktrees
man="$tmp/rwe2e-man-again.$$"
cp "$(ls -t "$tmp"/rwe2e-man.* | head -1)" "$man"
out2=$(sh "$root/scripts/init-wave.sh" "$man" 2>&1)
if printf '%s\n' "$out2" | grep -q 'already exists\|already initialised'; then
  ok "init: refuses existing run dir"
else
  fail "init: refuses existing run dir (got: $out2)"
fi
m2="$tmp/rwe2e-man-bad.$$"
sed 's/^TASKS=.*/TASKS="T3"/; s/^LABEL=.*/LABEL=s2bad/; s/^REVIEW_FOCUS=.*/REVIEW_FOCUS=correctness\nBUILDER_AGENT=aider/' "$man" > "$m2"
sh "$root/scripts/init-wave.sh" "$m2" 2>&1 | grep -q 'not in allowlist' \
  && ok "init: unknown builder agent refused" || fail "init: unknown builder agent refused"
rm -rf "$r" "$repo" "${repo}-worktrees" "$m2"

## 3 — C6: launch refusals
repo=$(new_repo); r=$(new_run "$repo" s3)
sh "$root/scripts/launch.sh" "$r" T1 2>&1 | grep -q 'TODO' && ok "launch: refuses TODO brief" || fail "launch: refuses TODO brief"
sh "$root/scripts/launch.sh" "$r" T9 2>&1 | grep -q 'unknown task' && ok "launch: refuses unknown task" || fail "launch: refuses unknown task"
full_briefs "$r"
sh "$root/scripts/launch.sh" "$r" T1 >/dev/null 2>&1
sh "$root/scripts/launch.sh" "$r" T1 2>&1 | grep -q 'already launched' && ok "launch: refuses double launch" || fail "launch: refuses double launch"
rm -rf "$r" "$repo" "${repo}-worktrees"

## 4 — C7: builder profiles dispatch per-CLI flags
repo=$(new_repo); r=$(new_run "$repo" s4 "BUILDER_AGENT=claude")
full_briefs "$r"
sh "$root/scripts/launch.sh" "$r" T1 >/dev/null 2>&1
: > "$ST/log"   # clear the launch-time log
sh "$root/scripts/run-agent.sh" "$r" T1 >/dev/null 2>&1
eq "$(grep -c '^claude \[' "$ST/log")" 1 "builder claude: invoked"
has '\[--permission-mode\] \[acceptEdits\]' "$(cat "$ST/log")" "builder claude: permission flags"
: > "$ST/log"
sed 's/^BUILDER_AGENT=.*/BUILDER_AGENT=codex/' "$r/wave.env" > "$r/wave.env.new" && mv "$r/wave.env.new" "$r/wave.env"
sh "$root/scripts/run-agent.sh" "$r" T2 >/dev/null 2>&1
has '\[--full-auto\]' "$(cat "$ST/log")" "builder codex: full-auto flag"
has 'model_reasoning_effort=high' "$(cat "$ST/log")" "builder codex: reasoning effort"
rm -rf "$r" "$repo" "${repo}-worktrees"

## 5 — C8: reviewer profiles dispatch + capture + REVIEW EXIT
repo=$(new_repo); r=$(new_run "$repo" s5 "REVIEW_AGENT=commandcode")
full_briefs "$r"
sh "$root/scripts/launch.sh" "$r" T1 >/dev/null 2>&1
fake_done "$r" T1
sh "$root/scripts/review-agent.sh" "$r" T1 >/dev/null 2>&1
eq "$(grep -c '^commandcode \[' "$ST/log")" 1 "reviewer commandcode: invoked"
has 'VERDICT: APPROVE' "$(cat "$r/T1.review.md")" "reviewer: output captured"
grep -q '^REVIEW EXIT' "$r/T1.review.md" && ok "reviewer: REVIEW EXIT appended" || fail "reviewer: REVIEW EXIT"
rm -rf "$r" "$repo" "${repo}-worktrees"

## 6 — C9: watch-review opens tab on done signal, records reviewed-head
repo=$(new_repo); r=$(new_run "$repo" s6)
full_briefs "$r"
sh "$root/scripts/launch.sh" "$r" T1 >/dev/null 2>&1
sh "$root/scripts/launch.sh" "$r" T2 >/dev/null 2>&1
fake_done "$r" T1
MAX_WAIT=3 sh "$root/scripts/watch-review.sh" "$r" >/dev/null 2>&1 &
wpid=$!
i=0; while [ $i -lt 20 ] && [ ! -f "$r/T1.reviewer.json" ]; do sleep 0.2; i=$((i+1)); done
[ -f "$r/T1.reviewer.json" ] && ok "watch-review: opens tab on done signal" || fail "watch-review: opens tab on done signal"
[ -f "$r/T1.reviewed-head" ] && ok "watch-review: records reviewed-head" || fail "watch-review: records reviewed-head"
kill "$wpid" 2>/dev/null; wait "$wpid" 2>/dev/null
rm -rf "$r" "$repo" "${repo}-worktrees"

## 7 — C10: send-fix refusals and happy path
repo=$(new_repo); r=$(new_run "$repo" s7)
full_briefs "$r"
sh "$root/scripts/launch.sh" "$r" T1 >/dev/null 2>&1
sh "$root/scripts/send-fix.sh" "$r" T1 2>&1 | grep -q 'fix.md first' && ok "send-fix: refuses missing fix.md" || fail "send-fix: refuses missing fix.md"
printf 'fix it\n' > "$r/T1.fix.md"
sh "$root/scripts/send-fix.sh" "$r" T1 2>&1 | grep -q 'not idle' && ok "send-fix: refuses non-idle builder" || fail "send-fix: refuses non-idle builder"
printf 'Ask your question\n' > "$ST/capture"
sh "$root/scripts/send-fix.sh" "$r" T1
has 'read .*T1.fix.md and apply' "$(cat "$ST/log")" "send-fix: sends fix text"
[ -f "$r/T1.fixprev" ] && ok "send-fix: records pre-fix HEAD" || fail "send-fix: records pre-fix HEAD"
sh "$root/scripts/send-fix.sh" "$r" T1 2>&1 | grep -q 'already sent' && ok "send-fix: refuses double send" || fail "send-fix: refuses double send"
rm -rf "$r" "$repo" "${repo}-worktrees"

## 8 — C11: watch-fix opens round-2 on fix commit + report marker
repo=$(new_repo); r=$(new_run "$repo" s8)
full_briefs "$r"
sh "$root/scripts/launch.sh" "$r" T1 >/dev/null 2>&1
wt1=$(wt_of_run "$r" T1)
printf 'report\n## Fix round 1\n' > "$wt1/REPORT-AGENT.md"
git -C "$wt1" commit -q --allow-empty -m fix1
git -C "$wt1" rev-parse HEAD~1 > "$r/T1.fixprev"
MAX_WAIT=3 sh "$root/scripts/watch-fix.sh" "$r" >/dev/null 2>&1 &
wpid=$!
i=0; while [ $i -lt 20 ] && [ ! -f "$r/T1.reviewer2.json" ]; do sleep 0.2; i=$((i+1)); done
[ -f "$r/T1.reviewer2.json" ] && ok "watch-fix: opens round-2 tab" || fail "watch-fix: opens round-2 tab"
kill "$wpid" 2>/dev/null; wait "$wpid" 2>/dev/null
rm -rf "$r" "$repo" "${repo}-worktrees"

## 9 — C12: close-idle conditions + dry-run + once-only
repo=$(new_repo); r=$(new_run "$repo" s9)
full_briefs "$r"
sh "$root/scripts/launch.sh" "$r" T1 >/dev/null 2>&1
wt1=$(wt_of_run "$r" T1)
printf '{"window_id":"w1","block_ids":["b1"]}\n' > "$r/T1.builder.json"
# not APPROVE -> stays open
printf 'VERDICT: CHANGES REQUESTED\nREVIEW EXIT\n' > "$r/T1.review.md"
: > "$ST/log"
sh "$root/scripts/close-idle.sh" "$r" >/dev/null 2>&1
grep -q 'close w1' "$ST/log" && fail "close-idle: closed builder with CHANGES REQUESTED" || ok "close-idle: builder with CHANGES REQUESTED stays open"
# APPROVE + dirty -> stays open
printf 'VERDICT: APPROVE\nREVIEW EXIT\n' > "$r/T1.review.md"
echo dirty > "$wt1/dirty.txt"
: > "$ST/log"
sh "$root/scripts/close-idle.sh" "$r" >/dev/null 2>&1
grep -q 'close w1' "$ST/log" && fail "close-idle: closed dirty builder" || ok "close-idle: dirty builder stays open"
rm "$wt1/dirty.txt"
# dry-run closes nothing, prints preview to stdout
: > "$ST/log"
out=$(sh "$root/scripts/close-idle.sh" "$r" --dry-run 2>&1)
grep -q 'close w1' "$ST/log" && fail "close-idle: dry-run closed a tab" || ok "close-idle: dry-run closes nothing"
has 'would close' "$out" "close-idle: dry-run previews"
# real close + once-only marker
sh "$root/scripts/close-idle.sh" "$r" >/dev/null 2>&1
[ -f "$r/T1.builder.closed" ] && ok "close-idle: closes APPROVE clean builder" || fail "close-idle: closes APPROVE clean builder"
: > "$ST/log"
sh "$root/scripts/close-idle.sh" "$r" >/dev/null 2>&1
eq "$(grep -c 'close w1' "$ST/log")" 0 "close-idle: never closes twice"
rm -rf "$r" "$repo" "${repo}-worktrees"

## 10 — C13/C14: dirty_of excludes only REPORT-AGENT.md; status stale flag
repo=$(new_repo); r=$(new_run "$repo" s10)
full_briefs "$r"
sh "$root/scripts/launch.sh" "$r" T1 >/dev/null 2>&1
wt1=$(wt_of_run "$r" T1)
echo stray > "$wt1/stray.txt"; printf 'report\n' > "$wt1/REPORT-AGENT.md"
line=$(sh "$root/scripts/status.sh" "$r" | grep '^T1 ')
dirtycol=$(printf '%s\n' "$line" | awk '{print $3}')
eq "$dirtycol" 1 "status: dirty counts stray (report excluded)"
printf '%s\n' abc > "$r/T1.reviewed-head"
has 'yes' "$(sh "$root/scripts/status.sh" "$r" | grep '^T1 ')" "status: stale=yes when HEAD past reviewed-head"
rm -rf "$r" "$repo" "${repo}-worktrees"

## 11 — C17: finish refuses unmerged / dirty; aborts before removing anything
repo=$(new_repo); r=$(new_run "$repo" s11 "TASKS=T1")
full_briefs "$r"
sh "$root/scripts/launch.sh" "$r" T1 >/dev/null 2>&1
wt1=$(wt_of_run "$r" T1)
git -C "$wt1" commit -q --allow-empty -m work
out=$(sh "$root/scripts/finish.sh" "$r" 2>&1); rc=$?
eq "$rc" 1 "finish: unmerged branch refused"
has 'BLOCKED' "$out" "finish: names BLOCKED task"
[ -d "$wt1" ] && ok "finish: refusal removed nothing" || fail "finish: refusal removed nothing"
git -C "$repo" merge -q fix/T1
echo dirty > "$wt1/d.txt"
out=$(sh "$root/scripts/finish.sh" "$r" 2>&1); rc=$?
eq "$rc" 1 "finish: dirty worktree refused"
rm "$wt1/d.txt"
out=$(sh "$root/scripts/finish.sh" "$r" 2>&1); rc=$?
eq "$rc" 0 "finish: merged+clean task passes"
rm -rf "$repo" "${repo}-worktrees"

## 12 — C18/C19: finish teardown; --dry-run removes nothing; --keep-run
repo=$(new_repo); r=$(new_run "$repo" s12 "TASKS=T1")
full_briefs "$r"
sh "$root/scripts/launch.sh" "$r" T1 >/dev/null 2>&1
wt1=$(wt_of_run "$r" T1)
git -C "$wt1" commit -q --allow-empty -m work
printf 'report\n' > "$wt1/REPORT-AGENT.md"
git -C "$repo" merge -q fix/T1
out=$(sh "$root/scripts/finish.sh" "$r" --dry-run 2>&1); rc=$?
eq "$rc" 0 "finish --dry-run: exits 0"
[ -d "$wt1" ] && ok "finish --dry-run: worktree kept" || fail "finish --dry-run: worktree kept"
has 'would remove' "$out" "finish --dry-run: previews actions"
sh "$root/scripts/finish.sh" "$r" --keep-run >/dev/null 2>&1
[ ! -d "$wt1" ] && ok "finish: worktree removed" || fail "finish: worktree removed"
if git -C "$repo" show-ref --verify --quiet refs/heads/fix/T1; then
  fail "finish: branch deleted"
else
  ok "finish: branch deleted"
fi
[ -d "$r" ] && ok "finish --keep-run: run dir kept" || fail "finish --keep-run: run dir kept"
sh "$root/scripts/finish.sh" "$r" >/dev/null 2>&1
[ ! -d "$r" ] && ok "finish: run dir removed on second pass" || fail "finish: run dir removed on second pass"
rm -rf "$repo" "${repo}-worktrees"

## 13 — C1: no merge/push/PR/deploy verbs in any script
bad=$(grep -nE 'git[[:space:]]+(-[^[:space:]]+[[:space:]]+)*(push|merge([[:space:]]|$))|gh[[:space:]]+pr[[:space:]]+create' "$root"/scripts/*.sh | grep -v 'merge-base' || true)
eq "$bad" "" "no push/PR/merge commands in scripts"

printf '%s\n' "----"
[ "$fails" = 0 ] && printf 'e2e: all passed\n' || { printf 'e2e: %d failure(s)\n' "$fails" >&2; exit 1; }
