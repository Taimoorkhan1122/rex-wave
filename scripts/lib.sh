# Shared helpers for rex-wave. Sourced by every script in scripts/. Caller sets `set -u`.
# Run dir state: wave.env, common.md, <task>.md (brief), <task>.builder.json, <task>.reviewer.json,
# <task>.review.md, <task>.reviewed-head, <task>.fix.md, <task>.fixprev, <task>.reviewer2.json, <task>.review2.md
# *.json files are the `rex window new --json` output (window_id, block_ids).

die() { printf 'rex-wave: %s\n' "$*" >&2; exit 1; }

# load_env <run-dir>: source wave.env and set RUN
load_env() {
  [ -f "$1/wave.env" ] || die "no wave.env in $1"
  RUN=$1
  . "$1/wave.env"
}

is_task() { for _x in $TASKS; do [ "$_x" = "$1" ] && return 0; done; return 1; }
wt_of() { printf '%s/%s\n' "$WT_ROOT" "$1"; }
head_of() { git -C "$(wt_of "$1")" rev-parse HEAD 2>/dev/null; }
# dirty_of <task>: uncommitted files (REPORT-AGENT.md excluded, it is never committed)
dirty_of() { git -C "$(wt_of "$1")" status --porcelain -- ':!REPORT-AGENT.md' 2>/dev/null | wc -l | tr -d ' '; }
json_field() { jq -r "$2" "$1" 2>/dev/null; }
builder_win() { json_field "$RUN/$1.builder.json" '.window_id'; }
builder_blk() { json_field "$RUN/$1.builder.json" '.block_ids[0]'; }

# agent_cli <agent>: the binary name a profile runs; empty if unknown
agent_cli() {
  case $1 in
    commandcode) printf 'commandcode' ;;
    claude)      printf 'claude' ;;
    codex)       printf 'codex' ;;
    opencode)    printf 'opencode' ;;
    *) return 1 ;;
  esac
}

# builder_run <agent> <model> <task> <prompt-file>: interactive builder invocation (builder tab)
builder_run() {
  _a=$1; _m=$2; _t=$3; _f=$4
  case $_a in
    commandcode) exec commandcode "$(cat "$_f")" -t --yolo --skip-onboarding -m "$_m" -n "$_t" ;;
    claude)      exec claude "$(cat "$_f")" --permission-mode acceptEdits --dangerously-skip-permissions --model "$_m" ;;
    codex)       exec codex "$(cat "$_f")" --full-auto -m "$_m" -c model_reasoning_effort=high ;;
    opencode)    exec opencode run --format TUI -m "$_m" "$(cat "$_f")" ;;
    *) die "unknown builder agent: $_a" ;;
  esac
}

# reviewer_run <agent> <model> <title> <prompt> <outfile>: non-interactive reviewer invocation, output to outfile
reviewer_run() {
  _a=$1; _m=$2; _title=$3; _p=$4; _out=$5
  case $_a in
    opencode) exec opencode run --agent cavecrew-reviewer -m "$_m" --auto --title "$_title" "$_p" 2>&1 | tee "$_out" ;;
    claude)   exec claude -p "$_p" --model "$_m" --output-format text 2>&1 | tee "$_out" ;;
    codex)    codex exec --full-auto -m "$_m" --output-last-message "$_out" "$_p" >/dev/null 2>&1 ;;
    commandcode) exec commandcode -p "$_p" -m "$_m" 2>&1 | tee "$_out" ;;
    *) die "unknown reviewer agent: $_a" ;;
  esac
  printf 'REVIEW EXIT\n' >> "$_out"
}

# open_tab <label> <cwd> <json-out> <cmd> [args...]: background tab in $REX_SESSION; saves window JSON on success
open_tab() {
  _label=$1; _cwd=$2; _out=$3; shift 3
  _json=$(rex window new -s "$REX_SESSION" "$_label" -c "$_cwd" --keep-open --focus=false --json -- "$@") || return 1
  printf '%s\n' "$_json" > "$_out"
}

# tab_no <window-id>: 1-based tab position, so the user knows which tab to open
tab_no() {
  [ -n "$1" ] || return 0
  rex window ls -s "$REX_SESSION" -q --short=false 2>/dev/null | grep -nxF "$1" | cut -d: -f1
}

# verdict_of <review-md>: last "VERDICT: ..." line, empty if none
verdict_of() { grep -o 'VERDICT: [A-Z ]*' "$1" 2>/dev/null | tail -n 1 | sed 's/ *$//'; }

# review_state <launch-json> <review-md>: "-" not launched, "running", or the verdict
review_state() {
  if [ ! -f "$1" ]; then printf '%s\n' '-'; return; fi
  if ! grep -q '^REVIEW EXIT' "$2" 2>/dev/null; then printf '%s\n' 'running'; return; fi
  _v=$(verdict_of "$2")
  printf '%s\n' "${_v:-no verdict}"
}

# close_window <launch-json> <marker>: closes a tab once (marker records it). DRY=1 only prints.
close_window() {
  [ -f "$2" ] && return 0
  _w=$(json_field "$1" '.window_id')
  if [ "${DRY:-0}" = 1 ]; then printf 'would close %s (window %s)\n' "$1" "$_w"; return 0; fi
  rex window close -s "$REX_SESSION" "$_w" >/dev/null 2>&1 && : > "$2"
}
