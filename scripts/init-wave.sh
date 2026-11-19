#!/bin/sh
# usage: init-wave.sh <manifest.env> — run inside a Rex terminal. Creates $TMPDIR/rex-wave-<LABEL>/ (wave.env, common.md, brief stubs) and one worktree per task.
set -u
here=$(cd "$(dirname "$0")" && pwd)
. "$here/lib.sh"
man=${1:?usage: init-wave.sh <manifest.env>}
[ -f "$man" ] || die "manifest not found: $man"
. "$man"
: "${LABEL:?manifest needs LABEL}"
: "${REPO:?manifest needs REPO}"
: "${BASE:?manifest needs BASE}"
: "${TASKS:?manifest needs TASKS}"
: "${BUILDER_MODEL:?manifest needs BUILDER_MODEL}"
: "${REVIEW_MODEL:?manifest needs REVIEW_MODEL}"
: "${COAUTHOR:?manifest needs COAUTHOR}"
: "${TYPECHECK_CMD:?manifest needs TYPECHECK_CMD}"
: "${TEST_CMD:?manifest needs TEST_CMD}"
: "${REVIEW_FOCUS:?manifest needs REVIEW_FOCUS}"
: "${REX_SESSION:?run inside a Rex terminal (REX_SESSION unset)}"
BUILDER_AGENT=${BUILDER_AGENT:-commandcode}
REVIEW_AGENT=${REVIEW_AGENT:-opencode}
WT_ROOT=${WT_ROOT:-$REPO-worktrees}

printf '%s\n' "$LABEL" | grep -qxE '[A-Za-z0-9][A-Za-z0-9._-]*' || die "bad LABEL: $LABEL"
agent_cli "$BUILDER_AGENT" >/dev/null || die "BUILDER_AGENT not in allowlist: $BUILDER_AGENT (commandcode | claude | codex | opencode)"
agent_cli "$REVIEW_AGENT" >/dev/null || die "REVIEW_AGENT not in allowlist: $REVIEW_AGENT (opencode | claude | codex | commandcode)"
: "${BUILDER_MODEL:?manifest needs BUILDER_MODEL for agent $BUILDER_AGENT}"
: "${REVIEW_MODEL:?manifest needs REVIEW_MODEL for agent $REVIEW_AGENT}"
command -v "$(agent_cli "$BUILDER_AGENT")" >/dev/null || die "builder CLI not on PATH: $(agent_cli "$BUILDER_AGENT")"
command -v "$(agent_cli "$REVIEW_AGENT")" >/dev/null || die "reviewer CLI not on PATH: $(agent_cli "$REVIEW_AGENT")"
rex session inspect "$REX_SESSION" --json >/dev/null 2>&1 || die "Rex session not reachable: $REX_SESSION"
BASE_SHA=$(git -C "$REPO" rev-parse "$BASE^{commit}" 2>/dev/null) || die "BASE does not resolve in $REPO: $BASE"

for t in $TASKS; do
  printf '%s\n' "$t" | grep -qxE '[A-Za-z0-9][A-Za-z0-9-]*' || die "bad task name: $t"
  [ -e "$(wt_of "$t")" ] && die "worktree already exists: $(wt_of "$t")"
  git -C "$REPO" show-ref --verify --quiet "refs/heads/fix/$t" && die "branch fix/$t already exists"
done

tmp=${TMPDIR:-/tmp}; tmp=${tmp%/}
RUN="$tmp/rex-wave-$LABEL"
[ -e "$RUN/wave.env" ] && die "run dir already initialised: $RUN"

mkdir -p "$WT_ROOT" "$RUN" || die "cannot create $WT_ROOT or $RUN"
for t in $TASKS; do
  git -C "$REPO" worktree add "$(wt_of "$t")" -b "fix/$t" "$BASE" >/dev/null || die "worktree add failed for $t (created so far: see $WT_ROOT)"
done

cp "$man" "$RUN/wave.env" || die "cannot write wave.env"
{
  printf 'REX_SESSION=%s\n' "$REX_SESSION"
  printf 'WT_ROOT=%s\n' "$WT_ROOT"
  printf 'BASE_SHA=%s\n' "$BASE_SHA"
  printf 'RUN=%s\n' "$RUN"
  printf 'BUILDER_AGENT=%s\n' "$BUILDER_AGENT"
  printf 'REVIEW_AGENT=%s\n' "$REVIEW_AGENT"
} >> "$RUN/wave.env"

esc() { printf '%s' "$1" | sed -e 's/[\\/&|]/\\&/g'; }
sed -e "s|{{REPO}}|$(esc "$REPO")|g" \
    -e "s|{{WT_ROOT}}|$(esc "$WT_ROOT")|g" \
    -e "s|{{BASE}}|$(esc "$BASE")|g" \
    -e "s|{{BASE_SHA}}|$(esc "$BASE_SHA")|g" \
    -e "s|{{COAUTHOR}}|$(esc "$COAUTHOR")|g" \
    -e "s|{{TYPECHECK_CMD}}|$(esc "$TYPECHECK_CMD")|g" \
    -e "s|{{TEST_CMD}}|$(esc "$TEST_CMD")|g" \
    "$here/../templates/common.md" > "$RUN/common.md" || die "cannot render common.md"

stubs=""
for t in $TASKS; do
  if [ ! -f "$RUN/$t.md" ]; then
    sed -e "s|{{TASK}}|$(esc "$t")|g" "$here/../templates/brief.md" > "$RUN/$t.md" || die "cannot write brief stub $t"
    stubs="$stubs $t"
  fi
done

printf 'run dir:   %s\n' "$RUN"
printf 'base:      %s (%s)\n' "$BASE" "$BASE_SHA"
printf 'builder:   %s (%s)\n' "$BUILDER_AGENT" "$BUILDER_MODEL"
printf 'reviewer:  %s (%s)\n' "$REVIEW_AGENT" "$REVIEW_MODEL"
for t in $TASKS; do printf 'worktree:  %s (branch fix/%s)\n' "$(wt_of "$t")" "$t"; done
[ -n "$stubs" ] && printf 'briefs still TODO (write with Write tool):%s\n' "$stubs"
printf 'next: write each brief, then sh %s/launch.sh %s <task>\n' "$here" "$RUN"
