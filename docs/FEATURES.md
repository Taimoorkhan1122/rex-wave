# Features

Shipped feature inventory. "Verified by" points at the executing test
(suite:scenario) or the live check that proved it. Commits are on `main`.

| Feature | Script / surface | Verified by | Since |
|---|---|---|---|
| Manifest → run dir, worktree per task on `fix/<task>`, branch, brief stubs | `init-wave.sh` | e2e 1 | `bf4433a` |
| Init refusals: existing worktree/branch/run dir; bad manifest (unknown agent, CLI not on PATH, missing model id) | `init-wave.sh` | e2e 2 | `bf4433a` / `e1d1727` |
| Parallel builder launch into visible Rex tabs, scoped to its worktree | `launch.sh` | e2e 4 (profile dispatch) | `bf4433a` |
| Launch refusals: TODO in brief, double-launch, unknown task, missing worktree | `launch.sh` | e2e 3 | `bf4433a` |
| Per-wave builder/reviewer CLI choice: commandcode, claude, codex, opencode via `lib.sh` profiles | `lib.sh`, `run-agent.sh`, reviewers | e2e 1/3/4/5 | `e1d1727` |
| Round-1 reviewer tab per finished task; verdict `VERDICT: APPROVE` / `CHANGES REQUESTED` parsed | `review-agent.sh`, `lib.sh verdict_of` | e2e 6/7 | `ea79a01` |
| Round-2 reviewer verifying each round-1 finding fixed / not fixed / partial | `review2-agent.sh` | e2e 6 | `ea79a01` |
| Background watcher opening reviewer tabs as builders finish; MAX_WAIT give-up naming stragglers | `watch-review.sh` | e2e 6/7 | `76adf19` |
| Fix delivery to an idle-at-prompt builder only; records pre-fix HEAD | `send-fix.sh` | e2e 6 | `5abf234` |
| Round-2 review trigger after fix commit + `## Fix round 1` marker | `watch-fix.sh` | e2e 8 | `76adf19` |
| Status: commits since base, dirty files, report/fix/review state, `stale` flag | `status.sh` | e2e 7/8 | `dbec6a0` |
| Tab cleanup: never closes dirty or running builders | `close-idle.sh` | e2e 12 | `dbec6a0` |
| Merge-verified teardown: refuses unmerged/uncommitted; `--dry-run` | `finish.sh` | e2e 11 | `18c19b0` |
| Completion pings to the invoking block (line + bell + OSC 9) per reviewable task | `watch-done.sh` | live fixture (ADR-0007) | `5c6954b` |
| lib.sh state-logic selfcheck (24 asserts) | `selfcheck.sh` | CI + local | `39cc96f` |
| Hermetic e2e suite (44 asserts): stub rex, one agent stub as all four CLIs, stubbed sleep | `e2e/run.sh` | CI | `63c17f6` |
| Claim-to-test coverage matrix C1–C20 | `docs/CLAIMS.md` | e2e suite | `63c17f6` |
| CI: shellcheck + selfcheck + e2e on push/PR | `.github/workflows/ci.yml` | runs 44527487426, 44528195995, v0.1.1 run | `e148647` |

## Hard rules (feature: the safety envelope)

- Scripts never merge, push, open a PR, or deploy — e2e 13 (static) + 11.
- `REPORT-AGENT.md` is never committed — dirty-file filtering in
  `status.sh`, excluded from reviews.
- Agents are told (SKILL.md) the same rules that scripts enforce.
