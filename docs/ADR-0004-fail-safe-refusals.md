# ADR-0004: Fail-safe refusals over retries

Date: 2026-11-19 · Status: Accepted · Since: `bf4433a` (refine `ab0afff`)

## Context

Scripts run unattended next to live agent sessions. Silent retries or
best-effort fallbacks could double-launch a builder, overwrite a brief,
close a working agent's tab, or destroy unmerged work.

## Decision

Every lifecycle script refuses (non-zero exit, explanatory message)
instead of retrying or degrading:

- `init-wave.sh` refuses an existing worktree, branch, or run dir.
- `launch.sh` refuses on TODO in the brief, double-launch, unknown task,
  missing worktree.
- `send-fix.sh` refuses while the builder is busy (not idle at its
  prompt).
- `close-idle.sh` never closes a builder that is dirty or running.
- `finish.sh` refuses anything not yet merged or uncommitted; `--dry-run`
  prints actions without performing them.

State lives in small JSON files per task (`<task>.builder.json`,
`review.md`, `fix.md`) inside the run dir — the run dir is the database.

## Consequences

- Refusal is always safe; a refused action is a re-runnable no-op.
- The cost is user-visible friction when state is legitimately stale —
  accepted, because the alternative is silent damage.
- Run-dir JSON is the single source of truth; no hidden caches.

## Verification

- e2e 2 (init refusals), 3 (launch refusals), 6 (send-fix idle gate),
  11 (finish refuses unmerged), 12 (close-idle dirty rule).
- CLAIMS C4, C6, C11–C14.
