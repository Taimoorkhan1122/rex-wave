# ADR-0001: One git worktree per task

Date: 2026-11-19 · Status: Accepted · Since: `bf4433a`

## Context

Running several coding agents on a single checkout means merge conflicts,
shared test-run lock contention, and agents clobbering each other's
edits. rex-wave's core job is parallel independent tasks.

## Decision

`init-wave.sh` creates one git worktree per task under `WT_ROOT`, each on
its own branch `fix/<task>`, all forked from the wave's `BASE_SHA`
(snapshot of the base branch at init time). A builder tab runs scoped to
its worktree only.

## Consequences

- No cross-contamination or lock contention; tasks are physically
  isolated.
- File ownership in the brief handles logical (not just physical)
  collisions: overlapping files are named and forbidden per task.
- Divergence between worktrees is expected and resolved at merge time by
  the user, never by script.
- Worktrees are removed by `finish.sh` only after the branch is verified
  merged.

## Verification

- e2e 1: worktree + branch per task exists after init.
- e2e 11: `finish.sh` refuses to remove an unmerged worktree/branch.
