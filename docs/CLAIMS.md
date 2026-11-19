# Claims → test coverage

Every claim made by README.md, SKILL.md, and contract-level comments in `scripts/*.sh`,
mapped to the behavioral test that backs it. Static checks are used only where the
claim is about the absence of a behavior (no test can "run" an action that must never
happen; grep is the honest proof).

## Test suites

| Suite | Command | Needs |
|---|---|---|
| selfcheck | `sh scripts/selfcheck.sh` | jq, grep, git |
| e2e | `sh e2e/run.sh` | sh, git, jq; stub `rex`/agent CLIs on PATH (hermetic, no network) |

## Claims

| # | Claim (source) | Test |
|---|---|---|
| C1 | Nothing ever merges, pushes, opens a PR, or deploys by script (README, SKILL hard rules) | e2e 13 (static: no such command in scripts/) + e2e 11 (finish refuses unmerged) |
| C2 | Builder/reviewer CLI chosen per wave; defaults commandcode/opencode (README, SKILL) | e2e 1 (defaults), e2e 3 (unknown agent refused), e2e 4/5 (all four profiles dispatch) |
| C3 | `init-wave.sh` creates one worktree per task on `fix/<task>`, run dir, brief stubs; worktrees under `WT_ROOT` (README, SKILL 6) | e2e 1 |
| C4 | `init-wave.sh` refuses to overwrite anything — existing worktree, branch, or run dir (SKILL 6) | e2e 2 |
| C5 | Manifest validation: known agent names, CLI on PATH, model ids required, bad LABEL/task names refused (README agents table) | e2e 2, selfcheck (agent_cli allowlist) |
| C6 | `launch.sh` refuses while brief has TODO, on double-launch, unknown task, missing worktree (README, SKILL 7–8) | e2e 3 |
| C7 | Profiles dispatch correct per-CLI flags for all four builders; unknown builder dies (lib.sh contract) | e2e 4 |
| C8 | Reviewer profiles dispatch correct per-CLI invocation, capture output, append `REVIEW EXIT`; unknown reviewer dies (lib.sh contract) | e2e 5 |
| C9 | `watch-review.sh` opens a reviewer tab per task once `REPORT-AGENT.md` exists and HEAD moved past `BASE_SHA`; records `reviewed-head`; exits when all opened; gives up after `MAX_WAIT` naming laggards (SKILL 9) | e2e 6 |
| C10 | `send-fix.sh` refuses TODO fix brief, refuses double send, refuses non-idle builder (fail-safe on idle-string mismatch), sends text + Enter, records pre-fix HEAD (SKILL 13) | e2e 7 |
| C11 | `watch-fix.sh` opens round-2 reviewer once HEAD moved and report has `## Fix round 1`; gives up naming laggards (SKILL 14) | e2e 8 |
| C12 | `close-idle.sh` closes reviewer tabs only after `REVIEW EXIT`; closes builder only when latest verdict is APPROVE with no fix pending, no stale review, no uncommitted changes; `--dry-run` closes nothing; close is once-only via marker (README, SKILL 17) | e2e 9, selfcheck (close_window dry-run) |
| C13 | `dirty_of` excludes only `REPORT-AGENT.md` (lib.sh contract, SKILL 16) | e2e 9/10, selfcheck (dirty_of asserts) |
| C14 | `status.sh` reports commits/dirty/report/fix state per task, and `stale=yes` when HEAD moved past the reviewed HEAD (SKILL 16) | e2e 10, selfcheck (review_state) |
| C15 | Verdicts are parsed deterministically: last `VERDICT:` line wins, trailing spaces stripped, absent → empty (lib.sh, SKILL gotchas) | selfcheck (verdict_of asserts) |
| C16 | `review_state` distinguishes not-launched / running / exited-with-verdict / exited-without-verdict (lib.sh) | selfcheck |
| C17 | `finish.sh` requires branch merged into BASE and clean worktree per task; one BLOCKED task aborts before anything is removed (README, SKILL 19) | e2e 11 |
| C18 | `finish.sh` removes worktree, deletes branch with `-d` (only merged branches die), closes builder tab, removes run dir; removes untracked `REPORT-AGENT.md` first so worktree remove succeeds (SKILL 19, finish.sh comment) | e2e 12 |
| C19 | `finish.sh --dry-run` removes nothing; `--keep-run` keeps briefs/reviews (SKILL 19) | e2e 12 |
| C20 | Run-dir state read from `wave.env`, including session id — scripts work outside the initiating shell (SKILL gotchas) | every e2e scenario (scripts invoked as separate processes with only REX_E2E/PATH set) |
